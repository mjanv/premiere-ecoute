defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.Search do
  @moduledoc """
  Spotify search API.

  Searches Spotify catalog for albums, artists, and tracks with query string matching and field filters.
  """

  require Logger

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Parser
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track

  @doc """
  Searches Spotify catalog for albums.

  Queries Spotify for albums matching the search string. Returns up to 20 albums with metadata but without tracks.
  """
  @spec search_albums(String.t()) :: {:ok, list(Album.t())} | {:error, term()}
  def search_albums(query) when is_binary(query) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/search?q=#{URI.encode(query)}&type=album&limit=20")
    |> SpotifyApi.handle(200, fn %{"albums" => %{"items" => items}} ->
      Enum.map(items, fn item ->
        %Album{
          provider: :spotify,
          album_id: item["id"],
          name: item["name"],
          artist: Parser.parse_primary_artist(item["artists"]),
          release_date: Parser.parse_release_date(item["release_date"]),
          cover_url: Parser.parse_album_cover_url(item["images"]),
          tracks: [],
          total_tracks: item["total_tracks"]
        }
      end)
    end)
  end

  @doc """
  Searches Spotify catalog for an artist.

  Queries Spotify for artists matching the search string. Returns first matching artist's ID or nil if none found.
  """
  @spec search_artist(String.t()) :: {:ok, map() | nil} | {:error, term()}
  def search_artist(query) when is_binary(query) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/search?q=#{URI.encode(query)}&type=artist&limit=1")
    |> SpotifyApi.handle(200, fn
      %{"artists" => %{"items" => [%{"uri" => "spotify:artist:" <> id}]}} -> %{id: id}
      _ -> nil
    end)
  end

  @doc """
  Searches Spotify catalog for tracks.

  Accepts a keyword list with one of: query, artist, track, album.
  Builds the appropriate Spotify field filter query and returns a list of Track structs.
  """
  @spec search_tracks(Keyword.t()) :: {:ok, [Track.t()]} | {:error, term()}
  def search_tracks(query) when is_list(query) do
    q = build_track_query(query)

    SpotifyApi.api()
    |> SpotifyApi.get(url: "/search", params: [q: q, type: "track", limit: 20])
    |> SpotifyApi.handle(200, fn %{"items" => items} ->
      Enum.map(items, &parse_track/1)
    end)
  end

  @spec build_track_query(Keyword.t()) :: String.t()
  defp build_track_query(query) do
    cond do
      q = query[:query] -> q
      q = query[:artist] -> "artist:#{q}"
      q = query[:track] -> "track:#{q}"
      q = query[:album] -> "album:#{q}"
    end
  end

  @spec parse_track(map()) :: Track.t()
  defp parse_track(data) do
    %Track{
      provider: :spotify,
      track_id: data["id"],
      name: data["name"],
      track_number: data["track_number"] || 0,
      duration_ms: data["duration_ms"] || 0
    }
  end
end
