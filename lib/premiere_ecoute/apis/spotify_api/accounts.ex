defmodule PremiereEcoute.Apis.SpotifyApi.Accounts do
  @moduledoc """
  # Spotify OAuth2 Authentication

  Handles OAuth2 authentication flows with Spotify Web API, supporting both client credentials flow for public data access and authorization code flow for user-specific operations. Manages token generation, exchange, and refresh operations with comprehensive error handling and logging.
  """

  require Logger

  alias PremiereEcoute.Apis.SpotifyApi

  def client_credentials do
    SpotifyApi.api(:accounts)
    |> Req.post(url: "/token", body: "grant_type=client_credentials")
    |> case do
      {:ok, %{status: 200, body: %{"access_token" => token}}} ->
        {:ok, token}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify auth failed: #{status} - #{inspect(body)}")
        {:error, "Spotify authentication failed"}

      {:error, reason} ->
        Logger.error("Spotify auth request failed: #{inspect(reason)}")
        {:error, "Network error during authentication"}
    end
  end

  def authorization_url(state \\ nil) do
    "https://accounts.spotify.com/authorize?" <>
      URI.encode_query(%{
        response_type: "code",
        client_id: Application.get_env(:premiere_ecoute, :spotify_client_id),
        scope:
          "user-read-private user-read-email user-read-playback-state user-modify-playback-state user-read-currently-playing",
        redirect_uri: Application.get_env(:premiere_ecoute, :spotify_redirect_uri),
        state: state || random(16)
      })
  end

  def authorization_code(code, _state) do
    SpotifyApi.api(:accounts)
    |> Req.post(
      url: "/token",
      form: [
        grant_type: "authorization_code",
        code: code,
        redirect_uri: Application.get_env(:premiere_ecoute, :spotify_redirect_uri),
        client_id: Application.get_env(:premiere_ecoute, :spotify_client_id)
      ]
    )
    |> case do
      {:ok, %{status: 200, body: %{"token_type" => "Bearer"} = body}} ->
        {:ok,
         %{
           access_token: body["access_token"],
           refresh_token: body["refresh_token"],
           expires_in: body["expires_in"]
         }}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify auth failed: #{status} - #{inspect(body)}")
        {:error, "Spotify authentication failed: #{status} - #{inspect(body)}"}

      {:error, reason} ->
        Logger.error("Spotify auth request failed: #{inspect(reason)}")
        {:error, "Network error during authentication"}
    end
  end

  def renew_token(refresh_token) do
    SpotifyApi.api(:accounts)
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
