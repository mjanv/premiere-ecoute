defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.Playlists do
  @moduledoc """
  Spotify playlists API.

  Manages Spotify playlist operations including fetching playlists with tracks, creating user playlists, adding/removing/replacing tracks, and listing user's library playlists.
  """

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Parser
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track

  @limit 10
  @tracks_limit 100
  @items_limit 100

  @doc """
  Fetches a Spotify playlist by ID.

  Retrieves playlist metadata and all tracks from Spotify API, paginating through
  the tracks endpoint until all tracks are collected. Parses response into Playlist
  aggregate with tracks.
  """
  @spec get_playlist(String.t()) :: {:ok, Playlist.t()} | {:error, term()}
  def get_playlist(playlist_id) when is_binary(playlist_id) do
    with {:ok, {playlist, total}} <-
           SpotifyApi.api()
           |> SpotifyApi.get(url: "/playlists/#{playlist_id}")
           |> SpotifyApi.handle(200, &parse_playlist/1),
         {:ok, remaining_tracks} <- fetch_remaining_tracks(playlist_id, total) do
      {:ok, %{playlist | tracks: playlist.tracks ++ remaining_tracks}}
    end
  end

  defp fetch_remaining_tracks(_playlist_id, total) when total <= @tracks_limit, do: {:ok, []}

  defp fetch_remaining_tracks(playlist_id, total) do
    offsets = Enum.take_every(@tracks_limit..(total - 1), @tracks_limit)

    offsets
    |> Task.async_stream(&fetch_tracks_page(playlist_id, &1), ordered: true, max_concurrency: 5)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, tracks}}, {:ok, acc} -> {:cont, {:ok, acc ++ tracks}}
      {:ok, {:error, _} = err}, _acc -> {:halt, err}
      {:exit, reason}, _acc -> {:halt, {:error, reason}}
    end)
  end

  defp fetch_tracks_page(playlist_id, offset) do
    SpotifyApi.api()
    |> SpotifyApi.get(url: "/playlists/#{playlist_id}/tracks", params: [limit: @tracks_limit, offset: offset])
    |> SpotifyApi.handle(200, fn %{"items" => items} ->
      items |> Enum.filter(&valid_track_item?/1) |> Enum.map(&parse_track(&1, playlist_id))
    end)
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
  Handles more than 100 items by splitting into multiple requests (Spotify API limit).
  """
  @spec add_items_to_playlist(Scope.t(), String.t(), list(Track.t())) :: {:ok, map()} | {:error, term()}
  def add_items_to_playlist(scope, id, tracks) do
    tracks
    |> Enum.chunk_every(@items_limit)
    |> Enum.reduce_while({:ok, %{}}, fn chunk, _acc ->
      scope
      |> SpotifyApi.api()
      |> SpotifyApi.post(
        url: "/playlists/#{id}/tracks",
        json: %{"position" => 0, "uris" => Enum.map(chunk, fn t -> "spotify:track:#{track_id(t)}" end)}
      )
      |> SpotifyApi.handle(201, fn body -> body end)
      |> case do
        {:ok, _} = ok -> {:cont, ok}
        {:error, _} = err -> {:halt, err}
      end
    end)
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
      json: %{"uris" => Enum.map(tracks, fn t -> "spotify:track:#{track_id(t)}" end)}
    )
    |> SpotifyApi.handle(200, fn body -> body end)
  end

  @doc """
  Removes tracks from a playlist.

  Deletes specified tracks from the playlist by their track IDs.
  Handles more than 100 items by splitting into multiple requests (Spotify API limit).
  """
  @spec remove_playlist_items(Scope.t(), String.t(), list(Track.t())) :: {:ok, map()} | {:error, term()}
  def remove_playlist_items(scope, id, tracks) do
    tracks
    |> Enum.chunk_every(@items_limit)
    |> Enum.reduce_while({:ok, %{}}, fn chunk, _acc ->
      scope
      |> SpotifyApi.api()
      |> SpotifyApi.delete(
        url: "/playlists/#{id}/tracks",
        json: %{
          "tracks" => Enum.map(chunk, fn t -> %{"uri" => "spotify:track:#{track_id(t)}"} end)
        }
      )
      |> SpotifyApi.handle(200, fn body -> body end)
      |> case do
        {:ok, _} = ok -> {:cont, ok}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  # AIDEV-NOTE: both Album.Track and Playlist.Track implement provider/2 on their own module
  defp track_id(%{__struct__: mod} = track), do: mod.provider(track, :spotify)

  defp valid_track_item?(item), do: not is_nil(item["track"])

  @spec parse_playlist(map()) :: {Playlist.t(), integer()}
  defp parse_playlist(data) do
    tracks =
      if Map.has_key?(data["tracks"], "items") do
        data["tracks"]["items"]
        |> Enum.filter(&valid_track_item?/1)
        |> Enum.map(fn item -> parse_track(item, data["id"]) end)
      else
        []
      end

    playlist = %Playlist{
      provider: :spotify,
      playlist_id: data["id"],
      owner_name: data["owner"]["display_name"],
      owner_id: data["owner"]["id"],
      title: data["name"],
      cover_url: Parser.parse_album_cover_url(data["images"]),
      tracks: tracks
    }

    total = get_in(data, ["tracks", "total"]) || 0

    {playlist, total}
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
