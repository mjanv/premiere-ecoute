defmodule PremiereEcoute.Apis.SpotifyApi.Search do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.SpotifyApi.Parser
  alias PremiereEcoute.Discography.Album

  @doc """
  Search for Album

  Reference: https://developer.spotify.com/documentation/web-api/reference/search
  """
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
  Search for Artist

  Reference: https://developer.spotify.com/documentation/web-api/reference/search
  """
  def search_artist(query) when is_binary(query) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/search?q=#{URI.encode(query)}&type=artist&limit=1")
    |> SpotifyApi.handle(200, fn
      %{"artists" => %{"items" => [%{"uri" => "spotify:artist:" <> id}]}} -> id
      _ -> nil
    end)
  end
end
