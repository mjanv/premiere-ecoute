defmodule PremiereEcoute.Extension.Services.TrackSaverTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Extension.Services.TrackSaver
  alias PremiereEcoute.Playlists.PlaylistRule

  describe "save_track/3 with playlist rules" do
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

      # Create a library playlist and set it as the save tracks playlist
      library_playlist = library_playlist_fixture(user, %{title: "My Configured Playlist"})
      {:ok, _rule} = PlaylistRule.set_save_tracks_playlist(user, library_playlist)

      # Mock the Spotify API call to add the track
      expect(SpotifyApi, :add_items_to_playlist, fn %Scope{user: ^user}, playlist_id, tracks ->
        assert playlist_id == library_playlist.playlist_id
        assert [%PremiereEcoute.Discography.Album.Track{track_id: ^spotify_track_id}] = tracks
        {:ok, %{"snapshot_id" => "snapshot_123"}}
      end)

      result = TrackSaver.save_track(user_id, spotify_track_id)

      assert result == {:ok, "My Configured Playlist"}
    end

    test "returns error when no rule configured and no explicit search term", %{user: user} do
      user_id = user.twitch.user_id
      spotify_track_id = "spotify_track_456"

      # No mocks needed since we should return error immediately

      result = TrackSaver.save_track(user_id, spotify_track_id)

      assert result == {:error, :no_playlist_rule}
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

      result = TrackSaver.save_track(user_id, spotify_track_id)
      assert result == {:error, :no_user}
    end

    test "handles no spotify connection error", %{user: _user} do
      user_no_spotify =
        user_fixture(%{
          twitch: %{user_id: "user_no_spotify"}
        })

      user_id = user_no_spotify.twitch.user_id
      spotify_track_id = "some_track"

      result = TrackSaver.save_track(user_id, spotify_track_id)
      assert result == {:error, :no_spotify}
    end
  end

  # Helper function to create library playlists for testing
  defp library_playlist_fixture(user, attrs \\ %{}) do
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
