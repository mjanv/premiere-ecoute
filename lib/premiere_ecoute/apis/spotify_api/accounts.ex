defmodule PremiereEcoute.Apis.SpotifyApi.Accounts do
  @moduledoc """
  # Spotify OAuth2 Authentication

  Handles OAuth2 authentication flows with Spotify Web API, supporting both client credentials flow for public data access and authorization code flow for user-specific operations. Manages token generation, exchange, and refresh operations with comprehensive error handling and logging.
  """

  require Logger

  alias PremiereEcoute.Apis.SpotifyApi

  @scope "user-read-private user-read-email user-read-playback-state user-modify-playback-state user-read-currently-playing playlist-read-private playlist-read-collaborative playlist-modify-public playlist-modify-private"

  @doc """
  Obtains client credentials access token.

  Uses client credentials OAuth flow to get access token for public Spotify API operations.
  """
  @spec client_credentials() :: {:ok, map()} | {:error, term()}
  def client_credentials do
    SpotifyApi.accounts()
    |> SpotifyApi.post(url: "/token", body: "grant_type=client_credentials")
    |> SpotifyApi.handle(200, fn %{"access_token" => _} = body -> body end)
  end

  @doc """
  Generates Spotify OAuth authorization URL.

  Creates authorization URL with specified scope and state. Uses default scope for user operations if not provided. Generates random state if not specified.
  """
  @spec authorization_url(String.t() | nil, String.t() | nil) :: String.t()
  def authorization_url(scope \\ nil, state \\ nil) do
    SpotifyApi.url(:accounts)
    |> URI.parse()
    |> URI.merge(%URI{
      path: "/authorize",
      query:
        URI.encode_query(%{
          response_type: "code",
          client_id: Application.get_env(:premiere_ecoute, :spotify_client_id),
          redirect_uri: Application.get_env(:premiere_ecoute, :spotify_redirect_uri),
          scope: scope || @scope,
          state: state || random(16)
        })
    })
    |> URI.to_string()
  end

  @doc """
  Exchanges authorization code for access tokens.

  Completes OAuth authorization code flow by exchanging code for access and refresh tokens. Fetches user profile and returns user data with tokens.
  """
  @spec authorization_code(String.t(), String.t() | nil) :: {:ok, map()} | {:error, term()}
  def authorization_code(code, _state) do
    SpotifyApi.accounts()
    |> SpotifyApi.post(
      url: "/token",
      form: [
        grant_type: "authorization_code",
        code: code,
        redirect_uri: Application.get_env(:premiere_ecoute, :spotify_redirect_uri),
        client_id: Application.get_env(:premiere_ecoute, :spotify_client_id)
      ]
    )
    |> SpotifyApi.handle(200, fn %{"token_type" => "Bearer"} = body ->
      {:ok, user} = SpotifyApi.get_user_profile(body["access_token"])

      %{
        user_id: user["id"],
        email: user["email"],
        username: user["display_name"],
        display_name: user["display_name"],
        country: user["country"],
        product: user["product"],
        access_token: body["access_token"],
        refresh_token: body["refresh_token"],
        expires_in: body["expires_in"]
      }
    end)
  end

  @doc """
  Refreshes expired access token.

  Uses refresh token to obtain new access token. Returns new access token and updated refresh token if provided by Spotify.
  """
  @spec renew_token(String.t()) :: {:ok, map()} | {:error, term()}
  def renew_token(refresh_token) do
    SpotifyApi.accounts()
    |> Req.post(
      url: "/token",
      form: [
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_id: Application.get_env(:premiere_ecoute, :spotify_client_id)
      ]
    )
    |> case do
      {:ok, %{status: 200, body: %{"access_token" => access_token} = body}} ->
        {:ok,
         %{
           access_token: access_token,
           refresh_token: body["refresh_token"] || refresh_token,
           expires_in: body["expires_in"]
         }}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify token refresh failed: #{status} - #{inspect(body)}")
        {:error, "Spotify token refresh failed: #{status} - #{inspect(body)}"}

      {:error, reason} ->
        Logger.error("Spotify token refresh request failed: #{inspect(reason)}")
        {:error, "Network error during token refresh"}
    end
  end

  defp random(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, length)
  end
end
