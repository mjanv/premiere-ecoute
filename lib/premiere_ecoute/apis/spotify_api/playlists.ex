defmodule PremiereEcoute.Apis.SpotifyApi.Playlists do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Accounts.User.LibraryPlaylist
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.SpotifyApi.Parser
  alias PremiereEcoute.Sessions.Discography.Playlist
  alias PremiereEcoute.Sessions.Discography.Playlist.Track

  def get_playlist(playlist_id) when is_binary(playlist_id) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/playlists/#{playlist_id}")
    |> SpotifyApi.handle(200, &parse_playlist/1)
  end

  def get_library_playlists(scope) do
    scope
    |> SpotifyApi.api()
    |> SpotifyApi.get(url: "/me/playlists")
    |> SpotifyApi.handle(200, fn %{"items" => items} -> Enum.map(items, &parse_library_playlist/1) end)
  end

  def add_items_to_playlist(scope, id, tracks) do
    scope
    |> SpotifyApi.api()
    |> SpotifyApi.post(
      url: "/playlists/#{id}/tracks",
      json: %{"position" => 0, "uris" => Enum.map(tracks, fn t -> "spotify:track:#{t.spotify_id}" end)}
    )
    |> SpotifyApi.handle(201, fn body -> body end)
  end

  def remove_playlist_items(scope, id, tracks, snapshot) do
    scope
    |> SpotifyApi.api()
    |> SpotifyApi.delete(
      url: "/playlists/#{id}/tracks",
      json: %{
        "tracks" => Enum.map(tracks, fn t -> %{"uri" => "spotify:track:#{t.spotify_id}"} end),
        "snapshot_id" => snapshot["snapshot_id"]
      }
    )
    |> SpotifyApi.handle(200, fn body -> body end)
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

  def parse_library_playlist(data) do
    %LibraryPlaylist{
      provider: :spotify,
      playlist_id: data["id"],
      url: data["external_urls"]["spotify"],
      title: data["name"],
      description: data["description"],
      cover_url: Parser.parse_album_cover_url(data["images"]),
      public: data["public"],
      metadata: %{}
    }
  end
end
