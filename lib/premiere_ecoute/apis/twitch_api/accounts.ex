defmodule PremiereEcoute.Apis.TwitchApi.Accounts do
  @moduledoc """
  # Twitch OAuth2 Authentication

  Handles OAuth2 authentication flows with Twitch API, supporting both application access tokens for general API access and user authorization code flow for user-specific operations. Manages token caching, user profile retrieval, and automatic token refresh with comprehensive error handling and logging.
  """

  require Logger

  alias PremiereEcoute.Apis.TwitchApi

  def client_credentials do
    TwitchApi.api(:accounts)
    |> TwitchApi.post(
      url: "/token",
      headers: [{"Content-Type", "application/x-www-form-urlencoded"}],
      body: %{grant_type: "client_credentials"}
    )
    |> TwitchApi.handle(200, fn body -> body end)
  end

  def authorization_url(scope \\ nil, state \\ nil) do
    TwitchApi.url(:accounts)
    |> URI.parse()
    |> URI.merge(%URI{
      path: "/oauth2/authorize",
      query:
        URI.encode_query(%{
          response_type: "code",
          scope:
            scope ||
              "channel:manage:polls channel:read:polls channel:bot user:read:chat user:write:chat user:bot moderator:manage:announcements",
          client_id: Application.get_env(:premiere_ecoute, :twitch_client_id),
          redirect_uri: Application.get_env(:premiere_ecoute, :twitch_redirect_uri),
          state: state || random(16)
        })
    })
    |> URI.to_string()
  end

  def authorization_code(code) when is_binary(code) do
    TwitchApi.api(:accounts)
    |> TwitchApi.post(
      url: "/token",
      headers: [{"Content-Type", "application/x-www-form-urlencoded"}],
      body: %{
        code: code,
        grant_type: "authorization_code",
        redirect_uri: Application.get_env(:premiere_ecoute, :twitch_redirect_uri)
      }
    )
    |> TwitchApi.handle(200, fn %{"access_token" => token, "refresh_token" => refresh_token, "expires_in" => expires_in} ->
      {:ok, user} = TwitchApi.get_user(token)

      %{
        user_id: user["id"],
        access_token: token,
        refresh_token: refresh_token,
        expires_in: expires_in,
        username: user["login"],
        display_name: user["display_name"],
        broadcaster_type: user["broadcaster_type"]
      }
    end)
  end

  def renew_token(refresh_token) do
    TwitchApi.api(:accounts)
    |> TwitchApi.post(
      url: "/token",
      body: %{grant_type: "refresh_token", refresh_token: refresh_token}
    )
    |> TwitchApi.handle(200, fn %{"access_token" => access_token, "refresh_token" => refresh_token} = body ->
      %{
        access_token: access_token,
        refresh_token: refresh_token,
        expires_in: body["expires_in"]
      }
    end)
  end

  defp random(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, length)
  end
end
