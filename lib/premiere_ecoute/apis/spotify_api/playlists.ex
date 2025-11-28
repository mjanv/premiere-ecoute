defmodule PremiereEcoute.Apis.SpotifyApi.Playlists do
  @moduledoc """
  Spotify playlists API.

  Manages Spotify playlist operations including fetching playlists with tracks, creating user playlists, adding/removing/replacing tracks, and listing user's library playlists.
  """

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.SpotifyApi.Parser
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track

  @limit 10

  @doc """
  Fetches a Spotify playlist by ID.

  Retrieves playlist metadata and tracks from Spotify API. Parses response into Playlist aggregate with tracks.
  """
  @spec get_playlist(String.t()) :: {:ok, Playlist.t()} | {:error, term()}
  def get_playlist(playlist_id) when is_binary(playlist_id) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/playlists/#{playlist_id}")
    |> SpotifyApi.handle(200, &parse_playlist/1)
  end

  @doc """
  Fetches user's library playlists.

  Retrieves paginated list of playlists from authenticated user's library. Returns 10 playlists per page.
  """
  @spec get_library_playlists(Scope.t(), integer()) :: {:ok, list(LibraryPlaylist.t())} | {:error, term()}
  def get_library_playlists(scope, page \\ 1) do
    scope
    |> SpotifyApi.api()
    |> SpotifyApi.get(url: "/me/playlists", params: [limit: @limit, offset: @limit * (page - 1)])
    |> SpotifyApi.handle(200, fn %{"items" => items} -> Enum.map(items, &parse_library_playlist/1) end)
  end

  @doc """
  Creates a new playlist in user's Spotify library.

  Creates playlist with specified title, description, and public/private setting. Returns created playlist metadata.
  """
  @spec create_playlist(Scope.t(), LibraryPlaylist.t()) :: {:ok, LibraryPlaylist.t()} | {:error, term()}
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

  @doc """
  Adds tracks to a playlist.

  Inserts tracks at the beginning of the playlist. Tracks are added in the order provided.
  """
  @spec add_items_to_playlist(Scope.t(), String.t(), list(Track.t())) :: {:ok, map()} | {:error, term()}
  def add_items_to_playlist(scope, id, tracks) do
    scope
    |> SpotifyApi.api()
    |> SpotifyApi.post(
      url: "/playlists/#{id}/tracks",
      json: %{"position" => 0, "uris" => Enum.map(tracks, fn t -> "spotify:track:#{t.track_id}" end)}
    )
    |> SpotifyApi.handle(201, fn body -> body end)
  end

  @doc """
  Replaces all tracks in a playlist.

  Removes all existing tracks and replaces them with the provided tracks.
  """
  @spec replace_items_to_playlist(Scope.t(), String.t(), list(Track.t())) :: {:ok, map()} | {:error, term()}
  def replace_items_to_playlist(scope, id, tracks) do
    scope
    |> SpotifyApi.api()
    |> SpotifyApi.put(
      url: "/playlists/#{id}/tracks",
      json: %{"uris" => Enum.map(tracks, fn t -> "spotify:track:#{t.track_id}" end)}
    )
    |> SpotifyApi.handle(200, fn body -> body end)
  end

  @doc """
  Removes tracks from a playlist.

  Deletes specified tracks from the playlist by their track IDs.
  """
  @spec remove_playlist_items(Scope.t(), String.t(), list(Track.t())) :: {:ok, map()} | {:error, term()}
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

  @doc """
  Parses Spotify API playlist response into Playlist aggregate.

  Transforms raw Spotify playlist JSON into structured Playlist with tracks, metadata, and owner information.
  """
  @spec parse_playlist(map()) :: Playlist.t()
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

  @doc """
  Parses Spotify API track item into Track struct.

  Transforms raw track JSON from playlist response into structured Track with metadata, artist, and timing information.
  """
  @spec parse_track(map(), String.t()) :: Track.t()
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

  @doc """
  Parses Spotify API library playlist into LibraryPlaylist struct.

  Transforms raw library playlist JSON into structured LibraryPlaylist with metadata, visibility settings, and cover image.
  """
  @spec parse_library_playlist(map()) :: LibraryPlaylist.t()
  def parse_library_playlist(data) when is_map(data) do
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
