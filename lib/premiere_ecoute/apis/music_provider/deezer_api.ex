defmodule PremiereEcoute.Apis.MusicProvider.DeezerApi do
  @moduledoc """
  Deezer API client.

  Provides access to Deezer Web API for fetching playlist data. No authentication required as the Deezer API is public.
  """

  use PremiereEcouteCore.Api,
    api: :deezer,
    behaviours: [
      PremiereEcoute.Apis.MusicProvider.Albums,
      PremiereEcoute.Apis.MusicProvider.Playlists
    ]

  defmodule Behaviour do
    @moduledoc "Deezer API Behaviour"

    @callback placeholder() :: any()
    @optional_callbacks placeholder: 0
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
  @spec client_credentials() :: {:ok, map()}
  def client_credentials, do: {:ok, %{"access_token" => "", "expires_in" => 0}}

  # Albums
  defdelegate get_album(album_id), to: __MODULE__.Albums
  defdelegate get_track(track_id), to: __MODULE__.Tracks

  # Playlists
  defdelegate get_playlist(playlist_id), to: __MODULE__.Playlists
end
