defmodule PremiereEcoute.Apis.MusicProvider.DeezerApi do
  @moduledoc """
  Deezer API client.

  Provides access to Deezer Web API for fetching playlist data. No authentication required as the Deezer API is public.
  """

  use PremiereEcouteCore.Api,
    api: :deezer,
    behaviours: [PremiereEcoute.Apis.MusicProvider]

  defmodule Behaviour do
    @moduledoc "Deezer API Behaviour"

    alias PremiereEcoute.Discography.Playlist

    # Playlists
    @callback get_playlist(playlist_id :: String.t()) :: {:ok, Playlist.t()} | {:error, term()}
  end

  @doc """
  Creates a Req client for Deezer API.

  Configures base URL and headers. No authentication required as Deezer API is public.
  """
  @spec api :: Req.Request.t()
  def api do
    [
      base_url: url(:api),
      headers: [{"Content-Type", "application/json"}]
    ]
    |> new()
  end

  @doc """
  Returns empty client credentials.

  Deezer API is public and requires no authentication, so this returns empty credentials for compatibility with the API base module.
  """
  @spec client_credentials() :: {:ok, %{String.t() => String.t() | integer()}}
  def client_credentials, do: {:ok, %{"access_token" => "", "expires_in" => 0}}

  # Playlists
  defdelegate get_playlist(playlist_id), to: __MODULE__.Playlists
end
