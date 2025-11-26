defmodule PremiereEcouteWeb.Accounts.AuthController do
  @moduledoc """
  OAuth authentication controller for external providers.

  Handles OAuth flows for Twitch and Spotify authentication, managing authorization requests and callbacks, user registration with provider data, terms acceptance for new users, and session management with automatic login.
  """

  use PremiereEcouteWeb, :controller

  require Logger

  alias PremiereEcoute.Accounts.Services.AccountRegistration
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Consent
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.TwitchApi
  alias PremiereEcouteWeb.Static.Legal
  alias PremiereEcouteWeb.UserAuth

  def request(conn, %{"provider" => "twitch", "role" => role}) do
    client_id = Application.get_env(:premiere_ecoute, :twitch_client_id)
    redirect_uri = Application.get_env(:premiere_ecoute, :twitch_redirect_uri)

    if client_id && redirect_uri do
      redirect(conn, external: TwitchApi.authorization_url(String.to_existing_atom(role)))
    else
      conn
      |> put_flash(:error, "Twitch login not configured")
      |> redirect(to: ~p"/")
    end
  end

  def request(conn, %{"provider" => "spotify"}) do
    client_id = Application.get_env(:premiere_ecoute, :spotify_client_id)
    redirect_uri = Application.get_env(:premiere_ecoute, :spotify_redirect_uri)

    if client_id && redirect_uri do
      user = conn.assigns.current_scope.user
      id = user && user.id

      if id do
        redirect(conn, external: SpotifyApi.authorization_url(nil, to_string(id)))
      else
        conn
        |> put_flash(:error, "You must be logged in to connect Spotify")
        |> redirect(to: ~p"/")
      end
    else
      conn
      |> put_flash(:error, "Spotify login not configured")
      |> redirect(to: ~p"/")
    end
  end

  def callback(conn, %{"provider" => "twitch", "code" => code}) do
    with {:ok, auth_data} <- TwitchApi.authorization_code(code),
         {user, auth_data} when not is_nil(user) <- {User.get_user_by_email(auth_data.email), auth_data},
         {:ok, user} <- AccountRegistration.register_twitch_user(auth_data) do
      conn
      |> put_session(:user_return_to, ~p"/")
      |> put_flash(:info, "Successfully authenticated with Twitch!")
      |> PremiereEcouteWeb.UserAuth.log_in_user(user, %{})
    else
      {nil, auth_data} ->
        conn
        |> put_session(:pending_twitch_auth, %{auth_data: auth_data, timestamp: System.system_time(:second)})
        |> redirect(to: ~p"/users/terms-acceptance")

      {:error, reason} ->
        Logger.error("Twitch callback error: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Twitch authentication failed")
        |> redirect(to: ~p"/")
    end
  end

  def callback(conn, %{"provider" => "spotify", "code" => code, "state" => state}) do
    with {:ok, auth_data} <- SpotifyApi.authorization_code(code, state),
         {:ok, user} <- AccountRegistration.register_spotify_user(auth_data, state) do
      conn
      |> put_session(:user_return_to, ~p"/")
      |> put_flash(:info, "Successfully authenticated with Spotify!")
      |> UserAuth.log_in_user(user, %{})
    else
      {:error, _} ->
        conn
        |> put_flash(:error, "Failed to connect Spotify account")
        |> redirect(to: ~p"/")
    end
  end

  def callback(conn, %{"provider" => provider, "error" => error}) do
    Logger.error("OAuth #{provider} error: #{inspect(error)}")

    conn
    |> put_flash(:info, "#{String.capitalize(provider)} authentication failed")
    |> redirect(to: ~p"/")
  end

  def complete(conn, %{} = params) do
    with data <- Map.take(params, ["privacy", "cookies", "terms"]),
         true <- Enum.all?(["privacy", "cookies", "terms"], fn k -> data[k] == "true" end),
         documents <- %{privacy: Legal.document(:privacy), cookies: Legal.document(:cookies), terms: Legal.document(:terms)},
         %{auth_data: auth_data} <- get_session(conn, :pending_twitch_auth),
         {:ok, user} <- AccountRegistration.register_twitch_user(auth_data),
         {:ok, _} <- Consent.accept(user, documents) do
      conn
      |> delete_session(:pending_twitch_auth)
      |> put_session(:user_return_to, ~p"/home")
      |> put_flash(:info, "Welcome! Your account has been created successfully.")
      |> PremiereEcouteWeb.UserAuth.log_in_user(user, %{})
    else
      false ->
        conn
        |> put_flash(:error, "All terms must be accepted to complete registration.")
        |> redirect(to: ~p"/")

      {:error, _} ->
        conn
        |> put_flash(:error, "Registration failed. Please try again.")
        |> redirect(to: ~p"/")

      _ ->
        conn
        |> put_flash(:error, "Authentication session expired")
        |> redirect(to: ~p"/")
    end
  end
end
