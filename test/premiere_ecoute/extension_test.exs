defmodule PremiereEcoute.ExtensionTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Extension
  alias PremiereEcoute.Playlists.PlaylistRule

  describe "get_current_track/1" do
    setup do
      stub(SpotifyApi, :get_playback_state, fn _scope, _state -> {:ok, %{}} end)
      :ok
    end

    test "successfully gets current track via TrackReader delegation" do
      user =
        user_fixture(%{
          twitch: %{user_id: "broadcaster123"},
          spotify: %{user_id: "spotify_user_123"}
        })

      broadcaster_id = user.twitch.user_id

      expect(SpotifyApi, :get_playback_state, fn _scope, %{} ->
        {:ok,
         %{
           "is_playing" => true,
           "item" => %{
             "id" => "track_123",
             "name" => "Test Song",
             "artists" => [%{"name" => "Test Artist"}],
             "album" => %{"name" => "Test Album"},
             "track_number" => 1,
             "duration_ms" => 180_000,
             "preview_url" => nil
           }
         }}
      end)

      result = Extension.get_current_track(broadcaster_id)

      assert {:ok, track_data} = result
      assert track_data.name == "Test Song"
      assert track_data.artist == "Test Artist"
    end

    test "returns error when user not found via TrackReader delegation" do
      result = Extension.get_current_track("nonexistent")
      assert result == {:error, :no_user}
    end
  end

  describe "like_track/2" do
    setup do
      stub(SpotifyApi, :get_library_playlists, fn _scope -> {:ok, []} end)
      stub(SpotifyApi, :add_items_to_playlist, fn _scope, _id, _tracks -> {:ok, %{}} end)
      :ok
    end

    test "successfully likes track via TrackLiker delegation" do
      user =
        user_fixture(%{
          twitch: %{user_id: "user123"},
          spotify: %{user_id: "spotify_user_123"}
        })

      user_id = user.twitch.user_id
      spotify_track_id = "track_456"

      {:ok, library_playlist} =
        LibraryPlaylist.create(user, %{
          provider: :spotify,
          playlist_id: "playlist_123",
          title: "My Configured Playlist",
          url: "https://open.spotify.com/playlist/123",
          public: true,
          track_count: 42
        })

      {:ok, _rule} = PlaylistRule.set_save_tracks_playlist(user, library_playlist)

      expect(SpotifyApi, :add_items_to_playlist, fn _scope, _playlist_id, _tracks ->
        {:ok, %{"snapshot_id" => "snap_123"}}
      end)

      result = Extension.like_track(user_id, spotify_track_id)

      assert result == {:ok, "My Configured Playlist"}
    end

    test "returns error when user not found via TrackLiker delegation" do
      result = Extension.like_track("nonexistent", "some_track")
      assert result == {:error, :no_user}
    end
  end
end
