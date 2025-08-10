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
    with {:ok, auth_data} <- TwitchApi.authorization_code(code) do
      email = auth_data.email || "#{auth_data.username}@twitch.tv"

      # Check if user already exists
      case PremiereEcoute.Accounts.User.get_user_by_email(email) do
        nil ->
          # New user - redirect to terms acceptance
          conn
          |> put_session(:pending_twitch_auth, %{
            auth_data: auth_data,
            timestamp: System.system_time(:second)
          })
          |> redirect(to: ~p"/users/terms-acceptance")

        _user ->
          # Existing user - update tokens and log in
          case AccountRegistration.register_twitch_user(auth_data) do
            {:ok, updated_user} ->
              conn
              |> put_session(:user_return_to, ~p"/home")
              |> put_flash(:info, "Successfully authenticated with Twitch!")
              |> PremiereEcouteWeb.UserAuth.log_in_user(updated_user, %{})

            {:error, reason} ->
              Logger.error("Failed to update existing user tokens: #{inspect(reason)}")

              conn
              |> put_flash(:error, "Authentication failed")
              |> redirect(to: ~p"/")
          end
      end
    else
      {:error, reason} ->
        Logger.error("Twitch OAuth error: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Twitch authentication failed")
        |> redirect(to: ~p"/")
    end
  end

  def callback(conn, %{"provider" => "spotify", "code" => code, "state" => state}) do
    with {:ok, auth_data} <- SpotifyApi.authorization_code(code, state),
         {:ok, user} <- AccountRegistration.register_spotify_user(auth_data, state) do
      conn
      |> put_session(:user_return_to, ~p"/home")
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

  @doc """
  Complete user registration after terms acceptance.
  Called after TermsAcceptanceLive redirects here.
  """
  def complete(conn, %{"provider" => "twitch", "user_id" => user_id_str}) do
    case get_session(conn, :pending_twitch_auth) do
      %{auth_data: _auth_data} ->
        user_id = String.to_integer(user_id_str)

        case PremiereEcoute.Accounts.get_user!(user_id) do
          user when not is_nil(user) ->
            conn
            |> delete_session(:pending_twitch_auth)
            |> put_session(:user_return_to, ~p"/home")
            |> put_flash(:info, "Welcome! Your account has been created successfully.")
            |> PremiereEcouteWeb.UserAuth.log_in_user(user, %{})

          nil ->
            conn
            |> put_flash(:error, "User not found")
            |> redirect(to: ~p"/")
        end

      _ ->
        conn
        |> put_flash(:error, "Authentication session expired")
        |> redirect(to: ~p"/users/log-in")
    end
  end
end
