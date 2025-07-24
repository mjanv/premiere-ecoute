defmodule PremiereEcoute.Apis.SpotifyApi.Playlists do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.SpotifyApi.Parser
  alias PremiereEcoute.Sessions.Discography.Playlist
  alias PremiereEcoute.Sessions.Discography.Playlist.Track

  def get_playlist(playlist_id) when is_binary(playlist_id) do
    SpotifyApi.api(:web)
    |> Req.get(url: "/playlists/#{playlist_id}")
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, parse_playlist(body)}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify playlist fetch failed: #{status} - #{inspect(body)}")
        {:error, "Spotify API error: #{status}"}

      {:error, reason} ->
        Logger.error("Spotify request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  def parse_playlist(data) do
    %Playlist{
      spotify_id: data["id"],
      owner_name: data["owner"]["display_name"],
      spotify_owner_id: data["owner"]["id"],
      name: data["name"],
      cover_url: Parser.parse_album_cover_url(data["images"]),
      tracks: Enum.map(data["tracks"]["items"], &parse_track/1)
    }
  end

  def parse_track(data) do
    %Track{
      spotify_id: data["track"]["id"],
      album_spotify_id: data["track"]["album"]["id"],
      user_spotify_id: data["added_by"]["id"],
      name: data["track"]["name"],
      artist: Parser.parse_primary_artist(data["artists"]),
      duration_ms: data["track"]["duration_ms"] || 0,
      added_at: NaiveDateTime.from_iso8601!(data["added_at"])
    }
  end
end
