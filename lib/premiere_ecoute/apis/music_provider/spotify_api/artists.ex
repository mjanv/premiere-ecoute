defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.Artists do
  @moduledoc """
  Spotify artists API.

  Fetches artist top tracks from Spotify API.
  """

  require Logger

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Discography.Playlist

  @doc """
  Fetches an artist's top track.

  Retrieves the top tracks for a Spotify artist and returns the first one. Returns nil if no tracks found.
  """
  @spec get_artist_top_track(String.t()) :: {:ok, Playlist.Track.t() | nil} | {:error, term()}
  def get_artist_top_track(artist_id) when is_binary(artist_id) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/artists/#{artist_id}/top-tracks")
    |> SpotifyApi.handle(200, fn
      %{"tracks" => [track | _]} -> %Playlist.Track{track_id: track["id"], name: track["name"]}
      _ -> nil
    end)
  end
end
