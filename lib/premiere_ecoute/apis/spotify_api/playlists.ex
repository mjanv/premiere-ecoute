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

  def get_user_playlists(_scope) do
    SpotifyApi.api(:web)
    |> Req.get(url: "/me/playlists")
    |> case do
      {:ok, %{status: 200, body: %{"items" => items}}} ->
        {:ok, Enum.map(items, &parse_playlist/1)}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify playlists fetch failed: #{status} - #{inspect(body)}")
        {:error, "Spotify API error: #{status}"}

      {:error, reason} ->
        Logger.error("Spotify request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  def add_items_to_playlist(_scope, id, tracks) do
    SpotifyApi.api(:web)
    |> Req.post(
      url: "/playlists/#{id}/tracks",
      json: %{"position" => 0, "uris" => Enum.map(tracks, fn t -> "spotify:track:#{t.spotify_id}" end)}
    )
    |> case do
      {:ok, %{status: 201, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify add items to playlist failed: #{status} - #{inspect(body)}")
        {:error, "Spotify API error: #{status}"}

      {:error, reason} ->
        Logger.error("Spotify request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  def remove_playlist_items(_scope, id, tracks, snapshot) do
    SpotifyApi.api(:web)
    |> Req.delete(
      url: "/playlists/#{id}/tracks",
      json: %{
        "tracks" => Enum.map(tracks, fn t -> %{"uri" => "spotify:track:#{t.spotify_id}"} end),
        "snapshot_id" => snapshot["snapshot_id"]
      }
    )
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Spotify remove items to playlist failed: #{status} - #{inspect(body)}")
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
      tracks:
        if Map.has_key?(data["tracks"], "items") do
          Enum.map(data["tracks"]["items"], &parse_track/1)
        else
          []
        end
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
