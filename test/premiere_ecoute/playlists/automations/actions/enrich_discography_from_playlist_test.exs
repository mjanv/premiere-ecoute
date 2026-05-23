defmodule PremiereEcoute.Playlists.Automations.Actions.EnrichDiscographyFromPlaylistTest do
  use PremiereEcoute.DataCase, async: true

  import Hammox

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track
  alias PremiereEcoute.Playlists.Automations.Actions.EnrichDiscographyFromPlaylist

  setup :verify_on_exit!

  defp scope, do: user_scope_fixture(user_fixture())

  defp library_playlist(user, snapshot_id \\ nil) do
    playlist_id = "playlist_#{System.unique_integer([:positive])}"

    {:ok, playlist} =
      LibraryPlaylist.create(user, %{
        provider: :spotify,
        playlist_id: playlist_id,
        title: "New Music Friday",
        url: "https://open.spotify.com/playlist/#{playlist_id}",
        track_count: 1,
        metadata: if(snapshot_id, do: %{"snapshot_id" => snapshot_id}, else: %{})
      })

    playlist
  end

  defp spotify_playlist(playlist_id, snapshot_id, tracks) do
    %Playlist{
      provider: :spotify,
      playlist_id: playlist_id,
      snapshot_id: snapshot_id,
      tracks: tracks
    }
  end

  defp track(album_id, artist_id) do
    %Track{
      provider: :spotify,
      track_id: "track_#{System.unique_integer([:positive])}",
      album_id: album_id,
      artist_id: artist_id,
      playlist_id: "playlist_123",
      name: "Some Track",
      artist: "Some Artist",
      duration_ms: 200_000,
      added_at: ~N[2025-01-01 00:00:00]
    }
  end

  describe "validate/1" do
    test "valid with playlist" do
      assert :ok = EnrichDiscographyFromPlaylist.validate(%{"playlist" => "playlist123"})
    end

    test "invalid without playlist" do
      assert {:error, _} = EnrichDiscographyFromPlaylist.validate(%{})
    end
  end

  describe "execute/3" do
    test "skips enrichment when snapshot_id is unchanged" do
      scope = scope()
      lp = library_playlist(scope.user, "snap_v1")
      playlist = spotify_playlist(lp.playlist_id, "snap_v1", [track("album1", "artist1")])

      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)

      assert {:ok, %{"skipped" => true}} =
               EnrichDiscographyFromPlaylist.execute(%{"playlist" => lp.playlist_id}, %{}, scope)
    end

    test "skips already-known albums without API calls" do
      scope = scope()
      lp = library_playlist(scope.user, "snap_v1")

      {:ok, artist} = Artist.create_if_not_exists(%{name: "Known Artist", provider_ids: %{spotify: "artist1"}})
      {:ok, _album} = Album.create(album_fixture(%{provider_ids: %{spotify: "album1"}, artists: [artist]}))

      playlist = spotify_playlist(lp.playlist_id, "snap_v2", [track("album1", "artist1")])
      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)

      assert {:ok, %{"new_artists" => 0, "skipped_albums" => 1}} =
               EnrichDiscographyFromPlaylist.execute(%{"playlist" => lp.playlist_id}, %{}, scope)
    end

    test "schedules EnrichDiscographyWorker for unknown artist when album is missing" do
      scope = scope()
      lp = library_playlist(scope.user)

      playlist = spotify_playlist(lp.playlist_id, "snap_v1", [track("album_new", "artist_unknown")])
      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, %{"new_artists" => 1, "skipped_albums" => 0}} =
                 EnrichDiscographyFromPlaylist.execute(%{"playlist" => lp.playlist_id}, %{}, scope)

        assert_enqueued(
          worker: PremiereEcoute.Discography.Workers.EnrichDiscographyWorker,
          args: %{"spotify_id" => "artist_unknown"}
        )
      end)
    end

    test "schedules EnrichDiscographyWorker for known artist when album is missing" do
      scope = scope()
      lp = library_playlist(scope.user)

      {:ok, artist} = Artist.create_if_not_exists(%{name: "Known Artist", provider_ids: %{spotify: "artist_known"}})

      playlist = spotify_playlist(lp.playlist_id, "snap_v1", [track("album_new2", "artist_known")])
      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, %{"new_artists" => 1, "skipped_albums" => 0}} =
                 EnrichDiscographyFromPlaylist.execute(%{"playlist" => lp.playlist_id}, %{}, scope)

        assert_enqueued(
          worker: PremiereEcoute.Discography.Workers.EnrichDiscographyWorker,
          args: %{"id" => artist.id}
        )
      end)
    end

    test "deduplicates albums from multiple tracks on the same album" do
      scope = scope()
      lp = library_playlist(scope.user)

      playlist =
        spotify_playlist(lp.playlist_id, "snap_v1", [
          track("album_dup", "artist_unk2"),
          track("album_dup", "artist_unk2")
        ])

      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, %{"new_artists" => 1, "skipped_albums" => 0}} =
                 EnrichDiscographyFromPlaylist.execute(%{"playlist" => lp.playlist_id}, %{}, scope)

        assert_enqueued(
          worker: PremiereEcoute.Discography.Workers.EnrichDiscographyWorker,
          args: %{"spotify_id" => "artist_unk2"}
        )
      end)
    end

    test "updates snapshot_id in library playlist metadata after run" do
      scope = scope()
      lp = library_playlist(scope.user, "snap_old")
      playlist = spotify_playlist(lp.playlist_id, "snap_new", [])

      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)

      EnrichDiscographyFromPlaylist.execute(%{"playlist" => lp.playlist_id}, %{}, scope)

      updated = LibraryPlaylist.get_by_playlist_id(scope.user, lp.playlist_id)
      assert updated.metadata["snapshot_id"] == "snap_new"
    end

    test "propagates error when get_playlist fails" do
      scope = scope()
      lp = library_playlist(scope.user)

      expect(SpotifyApi, :get_playlist, fn _id -> {:error, :not_found} end)

      assert {:error, :not_found} =
               EnrichDiscographyFromPlaylist.execute(%{"playlist" => lp.playlist_id}, %{}, scope)
    end
  end
end
