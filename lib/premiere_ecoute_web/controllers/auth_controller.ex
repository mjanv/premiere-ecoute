defmodule PremiereEcouteWeb.AuthController do
  use PremiereEcouteWeb, :controller

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.TwitchApi

  def request(conn, %{"provider" => "spotify"}) do
    client_id = Application.get_env(:premiere_ecoute, :spotify_client_id)
    redirect_uri = Application.get_env(:premiere_ecoute, :spotify_redirect_uri)

    if client_id && redirect_uri do
      redirect(conn, external: SpotifyApi.authorization_url())
    else
      conn
      |> put_flash(:error, "Spotify login not configured")
      |> redirect(to: ~p"/")
    end
  end

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

  def callback(conn, %{"provider" => "spotify", "code" => code}) do
    case authenticate_spotify_user(code) do
      {:ok, spotify_data} ->
        # Store Spotify token in session for playback control
        conn
        |> put_session(:spotify_token, spotify_data.access_token)
        |> put_flash(:info, "Spotify connected! You can now control playback from the dashboard.")
        |> redirect(to: ~p"/")

      {:error, reason} ->
        Logger.error("Spotify OAuth failed: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Spotify authentication failed")
        |> redirect(to: ~p"/")
    end
  end

  def callback(conn, %{"provider" => "spotify", "error" => error}) do
    Logger.error("Spotify OAuth error: #{error}")

    conn
    |> put_flash(:info, "Spotify authentication failed")
    |> redirect(to: ~p"/")
  end

  def callback(conn, %{"provider" => "twitch", "code" => code}) do
    case TwitchAdapter.authenticate_user(code) do
      {:ok, auth_data} ->
        case find_or_create_user(auth_data) do
          {:ok, user} ->
            conn
            |> put_flash(:info, "Successfully authenticated with Twitch!")
            |> PremiereEcouteWeb.UserAuth.log_in_user(user)
            |> redirect(to: ~p"/")

          {:error, reason} ->
            Logger.error("Failed to create user from Twitch auth: #{inspect(reason)}")

            conn
            |> put_flash(:error, "Authentication failed")
            |> redirect(to: ~p"/")
        end

      {:error, reason} ->
        Logger.error("Twitch OAuth failed: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Twitch authentication failed")
        |> redirect(to: ~p"/")
    end
  end

  def callback(conn, %{"provider" => "twitch", "error" => error}) do
    Logger.error("Twitch OAuth error: #{error}")

    conn
    |> put_flash(:info, "Twitch authentication failed")
    |> redirect(to: ~p"/")
  end

  defp find_or_create_user(auth_data) do
    email = "#{auth_data.username}@twitch.tv"

    case Accounts.get_user_by_email(email) do
      nil ->
        # Create new user
        Accounts.register_user(%{
          email: email,
          password: Base.encode64(:crypto.strong_rand_bytes(32))
        })

      user ->
        {:ok, user}
    end
  end

  defp authenticate_spotify_user(code) do
    client_id = Application.get_env(:premiere_ecoute, :spotify_client_id)
    client_secret = Application.get_env(:premiere_ecoute, :spotify_client_secret)
    redirect_uri = "http://localhost:4000/auth/spotify/callback"

    if client_id && client_secret do
      token_url = "https://accounts.spotify.com/api/token"

      case Req.post(token_url,
             headers: [{"Content-Type", "application/x-www-form-urlencoded"}],
             body:
               URI.encode_query(%{
                 client_id: client_id,
                 client_secret: client_secret,
                 code: code,
                 grant_type: "authorization_code",
                 redirect_uri: redirect_uri
               })
           ) do
        {:ok, %{status: 200, body: %{"access_token" => token, "refresh_token" => refresh_token}}} ->
          {:ok,
           %{
             access_token: token,
             refresh_token: refresh_token
           }}

        {:ok, %{status: status, body: body}} ->
          Logger.error("Spotify OAuth failed: #{status} - #{inspect(body)}")
          {:error, "Spotify authentication failed"}

        {:error, reason} ->
          Logger.error("Spotify OAuth request failed: #{inspect(reason)}")
          {:error, "Network error during authentication"}
      end
    else
      {:error, "Spotify credentials not configured"}
    end
  end
end
