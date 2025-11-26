defmodule PremiereEcoute.Apis.SpotifyApi.Playlists do
  @moduledoc """
  Spotify playlists API.

  Manages Spotify playlist operations including fetching playlists with tracks, creating user playlists, adding/removing/replacing tracks, and listing user's library playlists.
  """

  require Logger

  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.SpotifyApi.Parser
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track

  @limit 10

  def get_playlist(playlist_id) when is_binary(playlist_id) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/playlists/#{playlist_id}")
    |> SpotifyApi.handle(200, &parse_playlist/1)
  end

  def get_library_playlists(scope, page \\ 1) do
    scope
    |> SpotifyApi.api()
    |> SpotifyApi.get(url: "/me/playlists", params: [limit: @limit, offset: @limit * (page - 1)])
    |> SpotifyApi.handle(200, fn %{"items" => items} -> Enum.map(items, &parse_library_playlist/1) end)
  end

  def create_playlist(scope, %LibraryPlaylist{} = playlist) do
    scope
    |> SpotifyApi.api()
    |> SpotifyApi.post(
      url: "/users/#{scope.user.spotify.user_id}/playlists",
      json: %{"name" => playlist.title, "description" => playlist.description, "public" => playlist.public}
    )
    |> SpotifyApi.handle(201, fn body ->
      %LibraryPlaylist{
        provider: :spotify,
        playlist_id: body["id"],
        title: body["name"],
        description: body["description"],
        url: body["external_urls"]["spotify"],
        cover_url: Parser.parse_album_cover_url(body["images"]),
        public: body["public"],
        track_count: 0,
        metadata: %{}
      }
    end)
  end

  def add_items_to_playlist(scope, id, tracks) do
    scope
    |> SpotifyApi.api()
    |> SpotifyApi.post(
      url: "/playlists/#{id}/tracks",
      json: %{"position" => 0, "uris" => Enum.map(tracks, fn t -> "spotify:track:#{t.track_id}" end)}
    )
    |> SpotifyApi.handle(201, fn body -> body end)
  end

  def replace_items_to_playlist(scope, id, tracks) do
    scope
    |> SpotifyApi.api()
    |> SpotifyApi.put(
      url: "/playlists/#{id}/tracks",
      json: %{"uris" => Enum.map(tracks, fn t -> "spotify:track:#{t.track_id}" end)}
    )
    |> SpotifyApi.handle(200, fn body -> body end)
  end

  def remove_playlist_items(scope, id, tracks) do
    scope
    |> SpotifyApi.api()
    |> SpotifyApi.delete(
      url: "/playlists/#{id}/tracks",
      json: %{
        "tracks" => Enum.map(tracks, fn t -> %{"uri" => "spotify:track:#{t.track_id}"} end)
      }
    )
    |> SpotifyApi.handle(200, fn body -> body end)
  end

  def parse_playlist(data) do
    %Playlist{
      provider: :spotify,
      playlist_id: data["id"],
      owner_name: data["owner"]["display_name"],
      owner_id: data["owner"]["id"],
      title: data["name"],
      cover_url: Parser.parse_album_cover_url(data["images"]),
      tracks:
        if Map.has_key?(data["tracks"], "items") do
          Enum.map(data["tracks"]["items"], fn item -> parse_track(item, data["id"]) end)
        else
          []
        end
    }
  end

  def parse_track(data, playlist_id) do
    %Track{
      provider: :spotify,
      track_id: data["track"]["id"],
      album_id: data["track"]["album"]["id"],
      user_id: data["added_by"]["id"],
      playlist_id: playlist_id,
      name: data["track"]["name"],
      artist: Parser.parse_primary_artist(data["track"]["artists"]),
      duration_ms: data["track"]["duration_ms"] || 0,
      added_at: NaiveDateTime.from_iso8601!(data["added_at"]),
      release_date: Parser.parse_release_date(data["track"]["album"]["release_date"])
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
