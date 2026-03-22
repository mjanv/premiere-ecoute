defmodule PremiereEcoute.Apis.MusicProvider.TidalApi.Albums do
  @moduledoc """
  Tidal albums API.

  Fetches album data from Tidal Open API v2 and parses into Album aggregates with tracks.

  AIDEV-NOTE: Track number is NOT in track attributes — it lives in the album's
  relationships.items.data[].meta.trackNumber. We build a track_number lookup map
  before processing included tracks.
  Duration is ISO 8601 duration string (e.g. "PT5M38S") — parsed via Parser.parse_duration_ms/1.
  """

  alias PremiereEcoute.Apis.MusicProvider.TidalApi
  alias PremiereEcoute.Apis.MusicProvider.TidalApi.Parser
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track

  @doc """
  Fetches a Tidal album by ID.

  Retrieves album metadata, tracks, cover art, and primary artist from Tidal API.
  Parses response into Album aggregate with tracks.
  """
  @spec get_album(String.t()) :: {:ok, Album.t()} | {:error, term()}
  def get_album(album_id) when is_binary(album_id) do
    TidalApi.api()
    |> TidalApi.get(
      url: "/albums",
      params: [
        {"filter[id]", album_id},
        {"include", "items,coverArt,artists"},
        {"countryCode", "US"}
      ]
    )
    |> TidalApi.handle(200, &parse_album/1)
  end

  @spec parse_album(map()) :: Album.t()
  def parse_album(data) do
    album_data = hd(data["data"])
    included = data["included"] || []

    # Build track number index from album items relationship meta
    track_number_index =
      get_in(album_data, ["relationships", "items", "data"]) |> build_track_number_index()

    # Extract cover URL from included artworks
    artwork_id = get_in(album_data, ["relationships", "coverArt", "data", Access.at(0), "id"])
    images = Parser.parse_artworks(included, artwork_id)
    cover_url = Parser.pick_cover_url(images)

    # Extract primary artist name
    artist =
      included
      |> Enum.find(&(&1["type"] == "artists"))
      |> then(fn
        nil -> "Unknown Artist"
        a -> a["attributes"]["name"]
      end)

    tracks =
      included
      |> Enum.filter(&(&1["type"] == "tracks"))
      |> Enum.map(fn track ->
        %Track{
          provider_ids: %{tidal: track["id"]},
          name: track["attributes"]["title"],
          track_number: Map.get(track_number_index, track["id"], 0),
          duration_ms: Parser.parse_duration_ms(track["attributes"]["duration"])
        }
      end)
      |> Enum.sort_by(& &1.track_number)

    %Album{
      provider_ids: %{tidal: album_data["id"]},
      name: album_data["attributes"]["title"],
      artist: artist,
      release_date: Parser.parse_release_date(album_data["attributes"]["releaseDate"]),
      cover_url: cover_url,
      total_tracks: album_data["attributes"]["numberOfItems"],
      tracks: tracks
    }
  end

  # Build %{track_id => track_number} from album items relationship data
  @spec build_track_number_index(list() | nil) :: map()
  defp build_track_number_index(nil), do: %{}

  defp build_track_number_index(items) do
    Map.new(items, fn item -> {item["id"], item["meta"]["trackNumber"]} end)
  end
end
