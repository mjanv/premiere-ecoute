defmodule PremiereEcoute.Apis.TwitchApi.Accounts do
  @moduledoc """
  # Twitch OAuth2 Authentication

  Handles OAuth2 authentication flows with Twitch API, supporting both application access tokens for general API access and user authorization code flow for user-specific operations. Manages token caching, user profile retrieval, and automatic token refresh with comprehensive error handling and logging.
  """

  require Logger

  def access_token do
    client_id = Application.get_env(:premiere_ecoute, :twitch_client_id)
    client_secret = Application.get_env(:premiere_ecoute, :twitch_client_secret)

    if client_id && client_secret do
      "https://id.twitch.tv/oauth2/token"
      |> Req.post(
        headers: [{"Content-Type", "application/x-www-form-urlencoded"}],
        body:
          URI.encode_query(%{
            client_id: client_id,
            client_secret: client_secret,
            grant_type: "client_credentials"
          })
      )
      |> case do
        {:ok, %{status: 200, body: %{"access_token" => token, "expires_in" => expires_in}}} ->
          Cachex.put(:tokens, :app_access_token, token, expire: expires_in * 1_000)
          {:ok, token}

        {:ok, %{status: status, body: body}} ->
          Logger.error("Twitch app token failed: #{status} - #{inspect(body)}")
          {:error, "Twitch app authentication failed"}

        {:error, reason} ->
          Logger.error("Twitch app token request failed: #{inspect(reason)}")
          {:error, "Network error during app authentication"}
      end
    else
      {:error, "Twitch credentials not configured"}
    end
  end

  def authorization_url do
    "https://id.twitch.tv/oauth2/authorize?" <>
      URI.encode_query(%{
        response_type: "code",
        client_id: Application.get_env(:premiere_ecoute, :twitch_client_id),
        scope:
          "channel:manage:polls channel:read:polls channel:bot user:read:chat user:write:chat user:bot moderator:manage:announcements",
        redirect_uri: Application.get_env(:premiere_ecoute, :twitch_redirect_uri),
        state: random(16)
      })
  end

  def authorization_code(code) when is_binary(code) do
    client_id = Application.get_env(:premiere_ecoute, :twitch_client_id)
    client_secret = Application.get_env(:premiere_ecoute, :twitch_client_secret)
    redirect_uri = Application.get_env(:premiere_ecoute, :twitch_redirect_uri)

    if client_id && client_secret do
      "https://id.twitch.tv/oauth2/token"
      |> Req.post(
        headers: [{"Content-Type", "application/x-www-form-urlencoded"}],
        body:
          URI.encode_query(%{
            client_id: client_id,
            client_secret: client_secret,
            code: code,
            grant_type: "authorization_code",
            redirect_uri: redirect_uri
          })
      )
      |> case do
        {:ok,
         %{
           status: 200,
           body: %{
             "access_token" => token,
             "refresh_token" => refresh_token,
             "expires_in" => expires_in
           }
         }} ->
          case get_user_info(token) do
            {:ok, user_info} ->
              {:ok,
               %{
                 user_id: user_info["id"],
                 access_token: token,
                 refresh_token: refresh_token,
                 expires_in: expires_in,
                 username: user_info["login"],
                 display_name: user_info["display_name"],
                 broadcaster_type: user_info["broadcaster_type"]
               }}

            {:error, reason} ->
              {:error, reason}
          end

        {:ok, %{status: status, body: body}} ->
          Logger.error("Twitch OAuth failed: #{status} - #{inspect(body)}")
          {:error, "Twitch authentication failed"}

        {:error, reason} ->
          Logger.error("Twitch OAuth request failed: #{inspect(reason)}")
          {:error, "Network error during authentication"}
      end
    else
      {:error, "Twitch credentials not configured"}
    end
  end

  defp get_user_info(access_token) do
    "https://api.twitch.tv/helix/users"
    |> Req.get(
      headers: [
        {"Authorization", "Bearer #{access_token}"},
        {"Client-Id", Application.get_env(:premiere_ecoute, :twitch_client_id)}
      ]
    )
    |> case do
      {:ok, %{status: 200, body: %{"data" => [user | _]}}} ->
        {:ok, user}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twitch user info failed: #{status} - #{inspect(body)}")
        {:error, "Failed to get user info"}

      {:error, reason} ->
        Logger.error("Twitch user info request failed: #{inspect(reason)}")
        {:error, "Network error getting user info"}
    end
  end

  def renew_token(refresh_token) do
    client_id = Application.get_env(:premiere_ecoute, :twitch_client_id)
    client_secret = Application.get_env(:premiere_ecoute, :twitch_client_secret)

    if client_id && client_secret && refresh_token do
      "https://id.twitch.tv/oauth2/token"
      |> Req.post(
        headers: [{"Content-Type", "application/x-www-form-urlencoded"}],
        body:
          URI.encode_query(%{
            client_id: client_id,
            client_secret: client_secret,
            grant_type: "refresh_token",
            refresh_token: refresh_token
          })
      )
      |> case do
        {:ok,
         %{
           status: 200,
           body:
             %{
               "access_token" => access_token,
               "refresh_token" => new_refresh_token
             } = body
         }} ->
          {:ok,
           %{
             access_token: access_token,
             refresh_token: new_refresh_token,
             expires_in: body["expires_in"]
           }}

        {:ok, %{status: status, body: body}} ->
          Logger.error("Twitch token refresh failed: #{status} - #{inspect(body)}")
          {:error, "Twitch token refresh failed: #{status} - #{inspect(body)}"}

        {:error, reason} ->
          Logger.error("Twitch token refresh request failed: #{inspect(reason)}")
          {:error, "Network error during token refresh"}
      end
    else
      {:error, "Missing Twitch credentials or refresh token"}
    end
  end

  defp random(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, length)
  end
end
