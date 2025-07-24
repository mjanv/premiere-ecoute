defmodule PremiereEcoute.Apis.SpotifyApi.Albums do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.SpotifyApi.Parser
  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.Discography.Album.Track

  @doc """
  Get an album

  Reference: https://developer.spotify.com/documentation/web-api/reference/get-an-album
  """
  def get_album(album_id) when is_binary(album_id) do
    SpotifyApi.api(:web)
    |> Req.get(url: "/albums/#{album_id}")
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, parse_album_with_tracks(body)}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify album fetch failed: #{status} - #{inspect(body)}")
        {:error, "Spotify API error: #{status}"}

      {:error, reason} ->
        Logger.error("Spotify request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
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
