defmodule PremiereEcoute.Extension.Services.TrackLikerTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Events.TrackLiked
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Extension.Services.TrackLiker
  alias PremiereEcoute.Playlists.PlaylistRule

  describe "like_track/3 with playlist rules" do
    setup do
      user =
        user_fixture(%{
          twitch: %{user_id: "user123"},
          spotify: %{user_id: "spotify_user_123"}
        })

      {:ok, user: user}
    end

    test "uses configured playlist rule when no explicit search term provided", %{user: user} do
      user_id = user.twitch.user_id
      spotify_track_id = "spotify_track_123"

      # Create a library playlist and set it as the like tracks playlist
      library_playlist = library_playlist_fixture(user, %{title: "My Configured Playlist"})
      {:ok, _rule} = PlaylistRule.set_save_tracks_playlist(user, library_playlist)

      # Mock the Spotify API call to add the track
      expect(SpotifyApi, :add_items_to_playlist, fn %Scope{user: ^user}, playlist_id, tracks ->
        assert playlist_id == library_playlist.playlist_id
        assert [%PremiereEcoute.Discography.Album.Track{track_id: ^spotify_track_id}] = tracks
        {:ok, %{"snapshot_id" => "snapshot_123"}}
      end)

      result = TrackLiker.like_track(user_id, spotify_track_id)

      assert result == {:ok, "My Configured Playlist"}
    end

    test "returns error when no rule configured and no explicit search term", %{user: user} do
      user_id = user.twitch.user_id
      spotify_track_id = "spotify_track_456"

      # No mocks needed since we should return error immediately

      result = TrackLiker.like_track(user_id, spotify_track_id)

      assert result == {:error, :no_playlist_rule}
    end
  end

  describe "EventStore integration" do
    setup do
      user =
        user_fixture(%{
          twitch: %{user_id: "event_test_user"},
          spotify: %{user_id: "event_spotify_user"}
        })

      {:ok, user: user}
    end

    test "emits TrackLiked event to EventStore on successful like", %{} do
      # Create a unique user for this test
      unique_user_id = "event_test_single_#{System.unique_integer()}"

      user =
        user_fixture(%{
          twitch: %{user_id: unique_user_id},
          spotify: %{user_id: "spotify_event_single"}
        })

      spotify_track_id = "spotify_track_event"

      # Clean up any existing events for this broadcaster
      Store.delete_stream("like-#{unique_user_id}", :any_version, :hard)

      # Create a library playlist and set it as the like tracks playlist
      library_playlist = library_playlist_fixture(user, %{title: "Event Test Playlist"})
      {:ok, _rule} = PlaylistRule.set_save_tracks_playlist(user, library_playlist)

      # Mock the Spotify API call to add the track
      expect(SpotifyApi, :add_items_to_playlist, fn %Scope{user: ^user}, playlist_id, tracks ->
        assert playlist_id == library_playlist.playlist_id
        assert [%PremiereEcoute.Discography.Album.Track{track_id: ^spotify_track_id}] = tracks
        {:ok, %{"snapshot_id" => "snapshot_event"}}
      end)

      result = TrackLiker.like_track(unique_user_id, spotify_track_id)

      assert result == {:ok, "Event Test Playlist"}

      # Verify the event was stored in the EventStore
      events = Store.read("like-#{unique_user_id}")

      assert length(events) == 1

      assert [
               %TrackLiked{
                 id: ^unique_user_id,
                 # Atoms are serialized as strings in EventStore
                 provider: "spotify",
                 user_id: user_db_id,
                 track_id: ^spotify_track_id
               }
             ] = events

      # Verify user_id matches the database user id
      assert user_db_id == user.id
    end

    test "multiple track likes create multiple events in the same stream", %{} do
      # Create a unique user for this test
      unique_user_id = "event_test_multi_#{System.unique_integer()}"

      user =
        user_fixture(%{
          twitch: %{user_id: unique_user_id},
          spotify: %{user_id: "spotify_event_multi"}
        })

      # Clean up any existing events for this broadcaster
      Store.delete_stream("like-#{unique_user_id}", :any_version, :hard)

      # Create a library playlist and set it as the like tracks playlist
      library_playlist = library_playlist_fixture(user, %{title: "Multiple Events Playlist"})
      {:ok, _rule} = PlaylistRule.set_save_tracks_playlist(user, library_playlist)

      # Mock the Spotify API calls
      expect(SpotifyApi, :add_items_to_playlist, 2, fn %Scope{user: ^user}, _playlist_id, _tracks ->
        {:ok, %{"snapshot_id" => "snapshot_multi"}}
      end)

      # Save two different tracks
      result1 = TrackLiker.like_track(unique_user_id, "track_1")
      result2 = TrackLiker.like_track(unique_user_id, "track_2")

      assert result1 == {:ok, "Multiple Events Playlist"}
      assert result2 == {:ok, "Multiple Events Playlist"}

      # Verify both events were stored in the EventStore
      events = Store.read("like-#{unique_user_id}")

      assert length(events) == 2

      # Verify both tracks are in the events
      track_ids = Enum.map(events, & &1.track_id)
      assert "track_1" in track_ids
      assert "track_2" in track_ids

      # Verify all events have correct structure
      for event <- events do
        assert %TrackLiked{
                 id: ^unique_user_id,
                 provider: "spotify",
                 user_id: user_db_id
               } = event

        assert user_db_id == user.id
      end
    end

    test "events are available in both individual and aggregate streams", %{} do
      # Create a unique user for this test
      unique_user_id = "event_test_streams_#{System.unique_integer()}"

      user =
        user_fixture(%{
          twitch: %{user_id: unique_user_id},
          spotify: %{user_id: "spotify_event_streams"}
        })

      # Clean up any existing events for this broadcaster
      Store.delete_stream("like-#{unique_user_id}", :any_version, :hard)

      # Create a library playlist and set it as the like tracks playlist
      library_playlist = library_playlist_fixture(user, %{title: "Stream Test Playlist"})
      {:ok, _rule} = PlaylistRule.set_save_tracks_playlist(user, library_playlist)

      # Mock the Spotify API call
      expect(SpotifyApi, :add_items_to_playlist, fn %Scope{user: ^user}, _playlist_id, _tracks ->
        {:ok, %{"snapshot_id" => "snapshot_streams"}}
      end)

      # Save a track
      result = TrackLiker.like_track(unique_user_id, "stream_track_id")
      assert result == {:ok, "Stream Test Playlist"}

      # Verify event is in individual stream (like-<broadcaster_id>)
      individual_events = Store.read("like-#{unique_user_id}")
      assert length(individual_events) == 1

      # Verify event is also linked to aggregate stream (likes)
      # Note: The aggregate stream contains references to events, not the events themselves
      aggregate_events = Store.read("likes")
      # This should contain at least one event (may have more from other tests)
      assert length(aggregate_events) >= 1

      # At least one event in the aggregate should match our track
      assert Enum.any?(aggregate_events, fn event ->
               event.id == unique_user_id && event.track_id == "stream_track_id"
             end),
             "Expected to find our event in the aggregate 'likes' stream"
    end
  end

  describe "error handling across all scenarios" do
    setup do
      user =
        user_fixture(%{
          twitch: %{user_id: "error_user"},
          spotify: %{user_id: "spotify_error_user"}
        })

      {:ok, user: user}
    end

    test "handles user not found error", %{user: _user} do
      user_id = "nonexistent_user"
      spotify_track_id = "some_track"

      result = TrackLiker.like_track(user_id, spotify_track_id)
      assert result == {:error, :no_user}
    end

    test "handles no spotify connection error", %{user: _user} do
      user_no_spotify =
        user_fixture(%{
          twitch: %{user_id: "user_no_spotify"}
        })

      user_id = user_no_spotify.twitch.user_id
      spotify_track_id = "some_track"

      result = TrackLiker.like_track(user_id, spotify_track_id)
      assert result == {:error, :no_spotify}
    end
  end

  defp library_playlist_fixture(user, attrs) do
    default_attrs = %{
      provider: :spotify,
      playlist_id: "playlist_#{System.unique_integer([:positive])}",
      title: "Test Playlist",
      url: "https://open.spotify.com/playlist/test",
      public: true,
      track_count: 10
    }

    attrs = Map.merge(default_attrs, attrs)

    {:ok, playlist} = LibraryPlaylist.create(user, attrs)
    playlist
  end
end
