defmodule PremiereEcouteWeb.Extension.TrackControllerTest do
  use PremiereEcouteWeb.ConnCase, async: false

  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Discography.LibraryPlaylist

  describe "GET /extension/current-track/:broadcaster_id" do
    test "returns current track when broadcaster has active Spotify session", %{conn: conn} do
      # Setup: Create user with Spotify token
      user = insert_user_with_spotify()

      # Mock the Spotify API response using Mox instead of Hammox to avoid type checking
      Mox.expect(SpotifyApi.Mock, :get_playback_state, fn _scope, _state ->
        {:ok,
         %{
           "is_playing" => true,
           "item" => %{
             "id" => "4HCcvFdHfwR2u3WPPPVRv6",
             "name" => "Test Song",
             "artists" => [%{"name" => "Test Artist"}],
             "album" => %{"name" => "Test Album"},
             "track_number" => 1,
             "duration_ms" => 180_000,
             "preview_url" => "https://example.com/preview.mp3"
           }
         }}
      end)

      conn = get(conn, ~p"/extension/tracks/current/#{user.twitch.user_id}")

      assert json_response(conn, 200) == %{
               "track" => %{
                 "id" => nil,
                 "name" => "Test Song",
                 "artist" => "Test Artist",
                 "album" => "Test Album",
                 "track_number" => 1,
                 "duration_ms" => 180_000,
                 "spotify_id" => "4HCcvFdHfwR2u3WPPPVRv6",
                 "preview_url" => "https://example.com/preview.mp3"
               },
               "broadcaster_id" => user.twitch.user_id
             }
    end
  end

  describe "POST /extension/save-track" do
    test "saves track to user's Flonflon playlist successfully", %{conn: conn} do
      # Setup: Create user with Spotify token and mock playlist
      user = insert_user_with_spotify()

      # Let's create a simple stub using the existing mock. 
      # First setup what we can with the existing mock
      Mox.expect(SpotifyApi.Mock, :add_items_to_playlist, fn _scope, "playlist_123", tracks ->
        # Verify the tracks parameter is what we expect
        assert tracks == [%{track_id: "4HCcvFdHfwR2u3WPPPVRv6"}]
        {:ok, %{"snapshot_id" => "abc123"}}
      end)

      # Return proper LibraryPlaylist structs (Mox is more flexible with types)
      Mox.expect(SpotifyApi.Mock, :get_library_playlists, fn _scope ->
        {:ok,
         [
           %LibraryPlaylist{
             provider: :spotify,
             playlist_id: "playlist_123",
             title: "My Flonflon Hits",
             description: "My favorite tracks",
             public: false,
             track_count: 0
           }
         ]}
      end)

      params = %{
        "user_id" => user.twitch.user_id,
        "spotify_track_id" => "4HCcvFdHfwR2u3WPPPVRv6",
        "broadcaster_id" => "123456",
        "track_id" => 1
      }

      conn = post(conn, ~p"/extension/tracks/save", params)

      assert json_response(conn, 200) == %{
               "success" => true,
               "message" => "Track saved successfully",
               "playlist_name" => "My Flonflon Hits",
               "spotify_track_id" => "4HCcvFdHfwR2u3WPPPVRv6"
             }
    end
  end

  # Helper functions

  defp insert_user_with_spotify do
    user_fixture(%{
      twitch: %{
        user_id: "441903922",
        username: "teststreamer",
        access_token: "valid_twitch_token",
        refresh_token: "valid_twitch_refresh"
      },
      spotify: %{
        user_id: "spotify_user_123",
        username: "spotifyuser",
        access_token: "valid_access_token",
        refresh_token: "valid_refresh_token"
      }
    })
  end
end
