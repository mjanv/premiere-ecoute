defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.Search do
  @moduledoc """
  Spotify search API.

  Searches Spotify catalog for albums and artists with query string matching.
  """

  require Logger

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Parser
  alias PremiereEcoute.Discography.Album

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
end
