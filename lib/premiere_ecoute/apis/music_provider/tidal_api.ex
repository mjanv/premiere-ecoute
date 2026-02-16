defmodule PremiereEcoute.Apis.MusicProvider.TidalApi do
  @moduledoc """
  Tidal API client.

  Provides access to Tidal Web API for fetching playlists. Supports both user token authentication and client credentials flow for OAuth.
  """

  use PremiereEcouteCore.Api,
    api: :tidal,
    behaviours: [PremiereEcoute.Apis.MusicProvider]

  alias PremiereEcoute.Accounts.Scope

  defmodule Behaviour do
    @moduledoc "Tidal API Behaviour"

    alias PremiereEcoute.Discography.Playlist

    # Playlists
    @callback get_playlist(playlist_id :: String.t()) :: {:ok, Playlist.t()} | {:error, term()}
  end

  @doc """
  Creates a Req client for Tidal Web API with authentication.

  Accepts either a Scope struct with user access token or a raw access token string. Configures base URL and authorization header.
  """
  @spec api(Scope.t() | binary()) :: Req.Request.t()
  def api(%Scope{user: %{tidal: %{access_token: access_token}}}) do
    [
      base_url: url(:api),
      headers: [
        {"Authorization", "Bearer #{access_token}"},
        {"Content-Type", "application/json"}
      ]
    ]
    |> new()
  end

  def api(token) when is_binary(token) do
    [
      base_url: url(:api),
      headers: [
        {"Authorization", "Bearer #{token(token)}"},
        {"Content-Type", "application/json"}
      ]
    ]
    |> new()
  end

  @doc """
  Creates a Req client for Tidal Accounts API.

  Configures basic authentication with client ID and secret for OAuth token operations.
  """
  @spec accounts :: Req.Request.t()
  def accounts do
    id = Application.get_env(:premiere_ecoute, :tidal_client_id)
    secret = Application.get_env(:premiere_ecoute, :tidal_client_secret)

    [
      base_url: url(:accounts),
      headers: [
        {"Authorization", "Basic #{Base.encode64("#{id}:#{secret}")}"},
        {"Content-Type", "application/x-www-form-urlencoded"}
      ]
    ]
    |> new()
  end

  # Accounts
  defdelegate client_credentials, to: __MODULE__.Accounts

  # Playlists
  defdelegate get_playlist(playlist_id), to: __MODULE__.Playlists
end
