defmodule PremiereEcoute.Apis.SpotifyApi.Artists do
  @moduledoc """
  Spotify artists API.

  Fetches artist top tracks from Spotify API.
  """

  require Logger

  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Discography.Playlist

  def get_artist_top_track(artist_id) when is_binary(artist_id) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/artists/#{artist_id}/top-tracks")
    |> SpotifyApi.handle(200, fn
      %{"tracks" => [track | _]} -> %Playlist.Track{track_id: track["id"], name: track["name"]}
      _ -> nil
    end)
  end
end
