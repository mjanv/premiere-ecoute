defmodule PremiereEcoute.Apis.SpotifyApi.Search do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.SpotifyApi.Parser
  alias PremiereEcoute.Core.Entities.Album

  @doc """
  Search for Album

  Reference: https://developer.spotify.com/documentation/web-api/reference/search
  """
  def search_albums(query) when is_binary(query) do
    SpotifyApi.api(:web)
    |> Req.get(url: "/search?q=#{URI.encode(query)}&type=album&limit=20")
    |> case do
      {:ok, %{status: 200, body: %{"albums" => %{"items" => items}}}} ->
        items
        |> Enum.map(fn item ->
          %Album{
            spotify_id: item["id"],
            name: item["name"],
            artist: Parser.parse_primary_artist(item["artists"]),
            release_date: Parser.parse_release_date(item["release_date"]),
            cover_url: Parser.parse_album_cover_url(item["images"]),
            tracks: [],
            total_tracks: item["total_tracks"]
          }
        end)
        |> then(fn albums -> {:ok, albums} end)

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify search failed: #{status} - #{inspect(body)}")
        {:error, "Spotify API error: #{status}"}

      {:error, reason} ->
        Logger.error("Spotify request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end
end
