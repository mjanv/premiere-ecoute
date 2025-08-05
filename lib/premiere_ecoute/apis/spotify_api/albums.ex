defmodule PremiereEcoute.Apis.SpotifyApi.Albums do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.SpotifyApi.Parser
  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.Discography.Album.Track

  def get_album(album_id) when is_binary(album_id) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/albums/#{album_id}")
    |> SpotifyApi.handle(200, &parse_album_with_tracks/1)
  end

  def parse_album_with_tracks(data) do
    %Album{
      spotify_id: data["id"],
      name: data["name"],
      artist: Parser.parse_primary_artist(data["artists"]),
      release_date: Parser.parse_release_date(data["release_date"]),
      cover_url: Parser.parse_album_cover_url(data["images"]),
      total_tracks: data["total_tracks"],
      tracks:
        Enum.map(data["tracks"]["items"], fn track ->
          %Track{
            spotify_id: track["id"],
            album_id: data["id"],
            name: track["name"],
            track_number: track["track_number"] || 0,
            duration_ms: track["duration_ms"] || 0
          }
        end)
    }
  end
end
