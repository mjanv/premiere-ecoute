defmodule PremiereEcoute.Apis.Streaming.TwitchApi.Accounts do
  @moduledoc """
  # Twitch OAuth2 Authentication

  Handles OAuth2 authentication flows with Twitch API, supporting both application access tokens for general API access and user authorization code flow for user-specific operations. Manages token caching, user profile retrieval, and automatic token refresh with comprehensive error handling and logging.
  """

  require Logger

  alias PremiereEcoute.Apis.Streaming.TwitchApi

  @scopes [
    streamer:
      "user:read:email user:read:follows user:read:chat user:write:chat user:bot channel:manage:polls channel:read:polls channel:bot moderator:manage:announcements",
    viewer: "user:read:email user:read:follows"
  ]

  @doc """
  Obtains Twitch application access token using client credentials flow.

  Uses OAuth2 client credentials grant for server-to-server API authentication without user authorization.
  """
  @spec client_credentials() :: {:ok, map()} | {:error, term()}
  def client_credentials do
    TwitchApi.accounts()
    |> TwitchApi.post(
      url: "/token",
      headers: [{"Content-Type", "application/x-www-form-urlencoded"}],
      body: %{grant_type: "client_credentials"}
    )
    |> TwitchApi.handle(200, fn body -> body end)
  end

  @doc """
  Generates Twitch OAuth2 authorization URL for user authentication.

  Supports role-based scope selection (:streamer, :viewer) or custom scope string. Includes CSRF protection via state parameter.
  """
  @spec authorization_url(atom() | String.t() | nil, String.t() | nil) :: String.t()
  def authorization_url(role_or_scope, state \\ nil) do
    scope =
      case role_or_scope do
        nil -> @scopes[:viewer]
        role when is_atom(role) -> @scopes[role]
        scope when is_binary(scope) -> scope
      end

    TwitchApi.url(:accounts)
    |> URI.parse()
    |> URI.merge(%URI{
      path: "/oauth2/authorize",
      query:
        URI.encode_query(%{
          response_type: "code",
          scope: scope,
          client_id: Application.get_env(:premiere_ecoute, :twitch_client_id),
          redirect_uri: Application.get_env(:premiere_ecoute, :twitch_redirect_uri),
          state: state || random(16)
        })
    })
    |> URI.to_string()
  end

  @doc """
  Exchanges authorization code for user access tokens and profile data.

  Completes OAuth2 authorization code flow by exchanging code for access/refresh tokens. Fetches user profile and returns combined authentication data.
  """
  @spec authorization_code(String.t()) :: {:ok, map()} | {:error, term()}
  def authorization_code(code) when is_binary(code) do
    TwitchApi.accounts()
    |> TwitchApi.post(
      url: "/token",
      headers: [{"Content-Type", "application/x-www-form-urlencoded"}],
      body: %{
        code: code,
        grant_type: "authorization_code",
        redirect_uri: Application.get_env(:premiere_ecoute, :twitch_redirect_uri)
      }
    )
    |> TwitchApi.handle(200, fn %{"token_type" => "bearer"} = body ->
      {:ok, user} = TwitchApi.get_user_profile(body["access_token"])

      %{
        user_id: user["id"],
        email: user["email"],
        username: user["login"],
        display_name: user["display_name"],
        broadcaster_type: user["broadcaster_type"],
        access_token: body["access_token"],
        refresh_token: body["refresh_token"],
        expires_in: body["expires_in"],
        scope: body["scope"] || []
      }
    end)
  end

  @doc """
  Refreshes expired access token using refresh token.

  Obtains new access and refresh tokens from Twitch OAuth2 refresh token grant. Returns updated token credentials with expiration time.
  """
  @spec renew_token(String.t()) :: {:ok, map()} | {:error, term()}
  def renew_token(refresh_token) do
    TwitchApi.accounts()
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
