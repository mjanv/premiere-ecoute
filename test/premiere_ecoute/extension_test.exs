defmodule PremiereEcoute.ExtensionTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Extension
  alias PremiereEcoute.Apis.SpotifyApi.Mock, as: SpotifyApi

  # AIDEV-NOTE: Integration tests since Extension uses defdelegate - testing actual behavior
  describe "get_current_track/1" do
    setup do
      stub(SpotifyApi, :get_playback_state, fn _scope, _state -> {:ok, %{}} end)
      :ok
    end
    test "successfully gets current track via TrackReader delegation" do
      # Create user with Spotify connection
      user = user_fixture(%{
        twitch: %{user_id: "broadcaster123"},
        spotify: %{user_id: "spotify_user_123"}
      })

      broadcaster_id = user.twitch.user_id
      
      # Mock Spotify API response
      expect(SpotifyApi, :get_playback_state, fn _scope, %{} ->
        {:ok, %{
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

  describe "save_track/2" do
    setup do
      stub(SpotifyApi, :get_library_playlists, fn _scope -> {:ok, []} end)
      stub(SpotifyApi, :add_items_to_playlist, fn _scope, _id, _tracks -> {:ok, %{}} end)
      :ok
    end
    test "successfully saves track via TrackSaver delegation" do
      # Create user with Spotify connection
      user = user_fixture(%{
        twitch: %{user_id: "user123"},
        spotify: %{user_id: "spotify_user_123"}
      })

      user_id = user.twitch.user_id
      spotify_track_id = "track_456"

      # Mock get playlists - return proper LibraryPlaylist struct
      expect(SpotifyApi, :get_library_playlists, fn _scope ->
        {:ok, [%PremiereEcoute.Discography.LibraryPlaylist{
          playlist_id: "playlist_123",
          title: "My Flonflon Hits",
          provider: :spotify,
          track_count: 42,
          public: true
        }]}
      end)

      # Mock add track to playlist
      expect(SpotifyApi, :add_items_to_playlist, fn _scope, _playlist_id, _tracks ->
        {:ok, %{"snapshot_id" => "snap_123"}}
      end)

      result = Extension.save_track(user_id, spotify_track_id, "flonflon")

      assert result == {:ok, "My Flonflon Hits"}
    end

    test "returns error when user not found via TrackSaver delegation" do
      result = Extension.save_track("nonexistent", "some_track", "flonflon")
      assert result == {:error, :no_user}
    end
  end
end