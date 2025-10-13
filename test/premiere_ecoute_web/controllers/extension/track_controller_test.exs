defmodule PremiereEcouteWeb.Extension.TrackControllerTest do
  use PremiereEcouteWeb.ConnCase, async: false

  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.PlaylistRule

  describe "GET /extension/tracks/current/:broadcaster_id" do
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

    test "returns 404 when broadcaster has no active Spotify session", %{conn: conn} do
      # Setup: Create user with Spotify token
      user = insert_user_with_spotify()

      # Mock Spotify API to return no active session
      Mox.expect(SpotifyApi.Mock, :get_playback_state, fn _scope, _state ->
        {:ok, %{"is_playing" => false, "item" => nil}}
      end)

      conn = get(conn, ~p"/extension/tracks/current/#{user.twitch.user_id}")

      assert json_response(conn, 404) == %{
               "error" => "No track currently playing"
             }
    end

    test "returns 404 when broadcaster is not found", %{conn: conn} do
      # Use non-existent broadcaster ID
      conn = get(conn, ~p"/extension/tracks/current/nonexistent_broadcaster")

      assert json_response(conn, 404) == %{
               "error" => "Broadcaster not found or not connected to Spotify"
             }
    end
  end

  describe "POST /extension/tracks/save" do
    test "saves track to user's playlist successfully", %{conn: conn} do
      # Setup: Create user with Spotify token and playlist rule
      user = insert_user_with_spotify()

      # Create library playlist and set up playlist rule
      {:ok, library_playlist} =
        LibraryPlaylist.create(user, %{
          provider: :spotify,
          playlist_id: "playlist_123",
          title: "My Configured Playlist",
          url: "https://open.spotify.com/playlist/123",
          public: false,
          track_count: 0
        })

      {:ok, _rule} = PlaylistRule.set_save_tracks_playlist(user, library_playlist)

      # Mock adding track to playlist
      Mox.expect(SpotifyApi.Mock, :add_items_to_playlist, fn _scope, "playlist_123", tracks ->
        # Verify the tracks parameter is what we expect (now Track structs)
        assert [%PremiereEcoute.Discography.Album.Track{track_id: "4HCcvFdHfwR2u3WPPPVRv6"}] = tracks
        {:ok, %{"snapshot_id" => "abc123"}}
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
               "playlist_name" => "My Configured Playlist",
               "spotify_track_id" => "4HCcvFdHfwR2u3WPPPVRv6"
             }
    end

    test "returns error when no playlist rule configured", %{conn: conn} do
      # Setup: Create user with Spotify token but NO playlist rule
      user = insert_user_with_spotify()

      params = %{
        "user_id" => user.twitch.user_id,
        "spotify_track_id" => "4HCcvFdHfwR2u3WPPPVRv6",
        "broadcaster_id" => "123456",
        "track_id" => 1
      }

      conn = post(conn, ~p"/extension/tracks/save", params)

      assert json_response(conn, 404) == %{
               "error" => "No playlist rule configured. Please configure a playlist rule in the application settings."
             }
    end

    test "returns 404 when user not found", %{conn: conn} do
      params = %{
        "user_id" => "nonexistent_user",
        "spotify_track_id" => "4HCcvFdHfwR2u3WPPPVRv6",
        "broadcaster_id" => "123456",
        "track_id" => 1
      }

      conn = post(conn, ~p"/extension/tracks/save", params)

      assert json_response(conn, 404) == %{
               "error" => "User not found or not connected to Spotify"
             }
    end

    test "returns 400 when missing required parameters", %{conn: conn} do
      # Missing spotify_track_id parameter
      params = %{
        "user_id" => "123456",
        "broadcaster_id" => "123456",
        "track_id" => 1
      }

      conn = post(conn, ~p"/extension/tracks/save", params)

      assert json_response(conn, 400) == %{
               "error" => "Missing required parameters: user_id and spotify_track_id"
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
