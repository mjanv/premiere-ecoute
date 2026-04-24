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
  alias PremiereEcoute.Discography.Single

  @doc """
  Searches Spotify catalog for albums.

  Queries Spotify for albums matching the search string. Returns up to 20 albums with metadata but without tracks.
  """
  @spec search_albums(String.t()) :: {:ok, list(Album.t())} | {:error, term()}
  def search_albums(query) when is_binary(query) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/search", params: [q: query(query: query), type: "album", limit: 10])
    |> SpotifyApi.handle(200, fn %{"albums" => %{"items" => items}} ->
      Enum.map(items, fn item ->
        %Album{
          provider_ids: %{spotify: item["id"]},
          name: item["name"],
          artists: Parser.parse_artists(item["artists"]),
          release_date: Parser.parse_release_date(item["release_date"]),
          cover_url: Parser.parse_album_cover_url(item["images"]),
          tracks: [],
          total_tracks: item["total_tracks"]
        }
        |> Album.put_artist()
      end)
    end)
  end

  @doc """
  Searches Spotify catalog for an artist.

  Queries Spotify for artists matching the search string. Returns first matching artist's ID or nil if none found.
  """
  @spec search_artist(String.t()) :: {:ok, map() | nil} | {:error, term()}
  def search_artist(name) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/search", params: [q: query(query: name), type: "artist", limit: 1])
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
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/search", params: [q: query(query), type: "track", limit: 10])
    |> SpotifyApi.handle(200, fn %{"tracks" => %{"items" => items}} ->
      items |> Enum.map(&parse_track/1) |> Enum.reject(&is_nil/1)
    end)
  end

  @doc """
  Searches Spotify catalog for tracks and returns Single structs.

  Accepts a plain string query. Returns a list of Single structs with artist and cover.
  """
  @spec search_singles(String.t()) :: {:ok, [Single.t()]} | {:error, term()}
  def search_singles(query) when is_binary(query) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/search", params: [q: query, type: "track", limit: 10])
    |> SpotifyApi.handle(200, fn %{"tracks" => %{"items" => items}} ->
      items |> Enum.map(&parse_single/1) |> Enum.reject(&is_nil/1)
    end)
  end

  @doc """
  Searches Spotify catalog for any track regardless of album type.

  Returns Single structs with cover art and artists. Used for playlist submission
  where both album tracks and singles are valid submissions.
  """
  @spec search_any_track(String.t()) :: {:ok, [Single.t()]} | {:error, term()}
  def search_any_track(query) when is_binary(query) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/search", params: [q: query, type: "track", limit: 10])
    |> SpotifyApi.handle(200, fn %{"tracks" => %{"items" => items}} ->
      Enum.map(items, &parse_any_track/1)
    end)
  end

  defp query(query) do
    cond do
      q = query[:query] -> q
      q = query[:artist] -> "artist:#{q}"
      q = query[:track] -> "track:#{q}"
      q = query[:album] -> "album:#{q}"
    end
  end

  defp parse_any_track(data) do
    %Single{
      provider_ids: %{spotify: data["id"]},
      name: data["name"],
      artists: Parser.parse_artists(data["artists"]),
      duration_ms: data["duration_ms"] || 0,
      cover_url: Parser.parse_album_cover_url(data["album"]["images"])
    }
  end

  defp parse_single(%{"album" => %{"album_type" => "single"}} = data) do
    %Single{
      provider_ids: %{spotify: data["id"]},
      name: data["name"],
      artists: Parser.parse_artists(data["artists"]),
      duration_ms: data["duration_ms"] || 0,
      cover_url: Parser.parse_album_cover_url(data["album"]["images"])
    }
  end

  defp parse_single(_), do: nil

  defp parse_track(%{"album" => %{"album_type" => "album"}} = data) do
    %Track{
      provider_ids: %{spotify: data["id"]},
      name: data["name"],
      track_number: data["track_number"] || 0,
      duration_ms: data["duration_ms"] || 0
    }
  end

  defp parse_track(_), do: nil
end
