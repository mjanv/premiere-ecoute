defmodule PremiereEcouteWeb.AuthController do
  use PremiereEcouteWeb, :controller

  alias PremiereEcoute.Adapters.TwitchAdapter
  alias PremiereEcoute.Accounts
  require Logger

  def request(conn, %{"provider" => "twitch"}) do
    # Redirect to Twitch OAuth
    client_id = Application.get_env(:premiere_ecoute, :twitch_client_id)
    redirect_uri = Application.get_env(:premiere_ecoute, :twitch_redirect_uri)

    if client_id && redirect_uri do
      auth_url =
        "https://id.twitch.tv/oauth2/authorize?" <>
          URI.encode_query(%{
            client_id: client_id,
            redirect_uri: redirect_uri,
            response_type: "code",
            scope: "channel:manage:polls chat:read user:read:email"
          })

      redirect(conn, external: auth_url)
    else
      conn
      |> put_flash(:error, "Twitch OAuth not configured")
      |> redirect(to: ~p"/")
    end
  end

  def callback(conn, %{"provider" => "twitch", "code" => code}) do
    case TwitchAdapter.authenticate_user(code) do
      {:ok, auth_data} ->
        # Find or create user based on Twitch data
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
    |> put_flash(
      :info,
      "Twitch authentication was cancelled. Click 'Connect Twitch' to try again."
    )
    |> redirect(to: ~p"/")
  end

  defp find_or_create_user(auth_data) do
    email = "#{auth_data.username}@twitch.tv"

    case Accounts.get_user_by_email(email) do
      nil ->
        # Create new user
        Accounts.register_user(%{
          email: email,
          password: generate_random_password()
        })

      user ->
        {:ok, user}
    end
  end

  defp generate_random_password do
    :crypto.strong_rand_bytes(32) |> Base.encode64()
  end
end
