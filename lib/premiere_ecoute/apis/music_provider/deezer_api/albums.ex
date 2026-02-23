defmodule PremiereEcoute.Apis.MusicProvider.DeezerApi.Albums do
  @moduledoc """
  Deezer albums API.

  Fetches album data from Deezer API and parses into Album aggregates with tracks.
  """

  require Logger

  alias PremiereEcoute.Apis.MusicProvider.DeezerApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Parser
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track

  @doc """
  Fetches a Deezer album by ID.

  Retrieves album metadata and tracks from Deezer API. Parses response into Album aggregate with tracks.
  """
  @spec get_album(String.t()) :: {:ok, Album.t()} | {:error, term()}
  def get_album(album_id) when is_binary(album_id) do
    DeezerApi.api()
    |> DeezerApi.get(url: "/album/#{album_id}")
    |> DeezerApi.handle(200, &parse_album/1)
  end

  @spec parse_album(map()) :: Album.t()
  def parse_album(data) do
    %Album{
      provider: :deezer,
      album_id: data["id"],
      name: data["title"],
      artist: data["artist"]["name"],
      release_date: Parser.parse_release_date(data["release_date"]),
      cover_url: data["cover"],
      total_tracks: data["nb_tracks"],
      tracks:
        Enum.with_index(data["tracks"]["data"], fn track, i ->
          %Track{
            provider: :deezer,
            track_id: track["id"],
            album_id: track["album"]["id"],
            name: track["title"],
            track_number: i + 1,
            duration_ms: 1_000 * String.to_integer(track["duration"] || "0")
          }
        end)
    }
  end
end
