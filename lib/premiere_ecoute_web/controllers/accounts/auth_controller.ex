defmodule PremiereEcouteWeb.Accounts.AuthController do
  use PremiereEcouteWeb, :controller

  require Logger

  alias PremiereEcoute.Accounts.Services.AccountRegistration
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.TwitchApi
  alias PremiereEcouteWeb.UserAuth

  def request(conn, %{"provider" => "twitch"}) do
    client_id = Application.get_env(:premiere_ecoute, :twitch_client_id)
    redirect_uri = Application.get_env(:premiere_ecoute, :twitch_redirect_uri)

    if client_id && redirect_uri do
      redirect(conn, external: TwitchApi.authorization_url())
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
         {:ok, user} <- AccountRegistration.register_twitch_user(auth_data) do
      conn
      |> put_session(:user_return_to, ~p"/")
      |> put_flash(:info, "Successfully authenticated with Twitch!")
      |> PremiereEcouteWeb.UserAuth.log_in_user(user, %{})
    else
      {:error, reason} ->
        Logger.error("#{inspect(reason)}")

        conn
        |> put_flash(:error, "Twitch authentication failed")
        |> redirect(to: ~p"/")
    end
  end

  def callback(conn, %{"provider" => "spotify", "code" => code, "state" => state}) do
    with {:ok, auth_data} <- SpotifyApi.authorization_code(code, state),
         {:ok, user} <- AccountRegistration.register_spotify_user(auth_data, state) do
      conn
      |> put_session(:user_return_to, ~p"/users/account")
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
end
