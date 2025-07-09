defmodule PremiereEcouteWeb.Accounts.AuthController do
  use PremiereEcouteWeb, :controller

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.TwitchApi

  def request(conn, %{"provider" => "spotify"}) do
    client_id = Application.get_env(:premiere_ecoute, :spotify_client_id)
    redirect_uri = Application.get_env(:premiere_ecoute, :spotify_redirect_uri)

    if client_id && redirect_uri do
      # AIDEV-NOTE: Get current user ID and include in OAuth state
      user_id =
        case conn.assigns[:current_scope] do
          %{user: %{id: id}} -> to_string(id)
          _ -> nil
        end

      if user_id do
        authorization_url = SpotifyApi.authorization_url_with_state(user_id)
        redirect(conn, external: authorization_url)
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

  def callback(conn, %{"provider" => "spotify", "code" => code, "state" => state}) do
    Logger.info("Spotify callback started with code: #{String.slice(code, 0, 20)}... and state: #{state}")

    result =
      try do
        SpotifyApi.authorization_code(code, state)
      rescue
        e ->
          Logger.error("Exception in SpotifyApi.authorization_code: #{inspect(e)}")
          {:error, "Exception: #{inspect(e)}"}
      catch
        :exit, reason ->
          Logger.error("Exit in SpotifyApi.authorization_code: #{inspect(reason)}")
          {:error, "Exit: #{inspect(reason)}"}
      end

    Logger.info("SpotifyApi.authorization_code result: #{inspect(result)}")

    case result do
      {:ok, spotify_data} ->
        # AIDEV-NOTE: Get user from state parameter (user ID)
        user =
          case Integer.parse(state) do
            {user_id, ""} -> Accounts.get_user!(user_id)
            _ -> nil
          end

        Logger.info("Spotify callback - resolved user from state: #{inspect(user && user.id)}")

        case user do
          nil ->
            # AIDEV-NOTE: User not logged in, redirect to login
            conn
            |> put_flash(:error, "You must be logged in to connect Spotify")
            |> redirect(to: ~p"/")

          user ->
            case Accounts.User.update_spotify_tokens(user, spotify_data) do
              {:ok, _} ->
                conn
                |> put_flash(
                  :info,
                  "Spotify connected! You can now control playback from the dashboard."
                )
                |> redirect(to: ~p"/account")

              {:error, _changeset} ->
                Logger.error("Failed to store Spotify tokens for user #{user.id}")

                conn
                |> put_flash(:error, "Failed to connect Spotify account")
                |> redirect(to: ~p"/account")
            end
        end

      {:error, reason} ->
        Logger.error("Spotify OAuth failed: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Spotify authentication failed: #{reason}")
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
    case TwitchApi.authorization_code(code) do
      {:ok, auth_data} ->
        case find_or_create_user(auth_data) do
          {:ok, user} ->
            conn
            |> put_session(:user_return_to, ~p"/")
            |> put_flash(:info, "Successfully authenticated with Twitch!")
            |> PremiereEcouteWeb.UserAuth.log_in_user(user, %{})

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
    Logger.error("Twitch OAuth error: #{inspect(error)}")

    conn
    |> put_flash(:error, "Twitch authentication failed")
    |> redirect(to: ~p"/")
  end

  defp find_or_create_user(auth_data) do
    email = "#{auth_data.username}@twitch.tv"

    case Accounts.get_user_by_email(email) do
      nil ->
        # Create new user with Twitch auth data
        case Accounts.register_user(%{
               email: email,
               password: Base.encode64(:crypto.strong_rand_bytes(32))
             }) do
          {:ok, user} ->
            # Store Twitch auth data for new user
            Accounts.User.update_twitch_auth(user, auth_data)

          error ->
            error
        end

      user ->
        # Update existing user with latest Twitch auth data
        Accounts.User.update_twitch_auth(user, auth_data)
    end
  end
end
