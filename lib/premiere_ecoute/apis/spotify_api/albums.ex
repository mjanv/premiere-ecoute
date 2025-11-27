defmodule PremiereEcoute.Apis.SpotifyApi.Albums do
  @moduledoc """
  Spotify albums API.

  Fetches album data with tracks from Spotify API and parses into Album aggregates.
  """

  require Logger

  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.SpotifyApi.Parser
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track

  @doc """
  Fetches a Spotify album by ID.

  Retrieves album metadata and tracks from Spotify API. Parses response into Album aggregate with associated tracks.
  """
  @spec get_album(String.t()) :: {:ok, Album.t()} | {:error, term()}
  def get_album(album_id) when is_binary(album_id) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/albums/#{album_id}")
    |> SpotifyApi.handle(200, &parse_album_with_tracks/1)
  end

  def parse_album_with_tracks(data) do
    %Album{
      provider: :spotify,
      album_id: data["id"],
      name: data["name"],
      artist: Parser.parse_primary_artist(data["artists"]),
      release_date: Parser.parse_release_date(data["release_date"]),
      cover_url: Parser.parse_album_cover_url(data["images"]),
      total_tracks: data["total_tracks"],
      tracks:
        Enum.map(data["tracks"]["items"], fn track ->
          %Track{
            provider: :spotify,
            track_id: track["id"],
            album_id: data["id"],
            name: track["name"],
            track_number: track["track_number"] || 0,
            duration_ms: track["duration_ms"] || 0
          }
        end)
    }
  end
end
