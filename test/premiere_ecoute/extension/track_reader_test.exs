defmodule PremiereEcoute.Extension.TrackReaderTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Extension.TrackReader

  describe "get_current_track/1" do
    setup do
      user =
        user_fixture(%{
          twitch: %{user_id: "broadcaster123"},
          spotify: %{user_id: "spotify_user_123"}
        })

      {:ok, user: user}
    end

    test "returns current playing track successfully", %{user: user} do
      broadcaster_id = user.twitch.user_id

      # Mock successful playback state response from Spotify
      playback_response = %{
        "is_playing" => true,
        "item" => %{
          "id" => "track_123",
          "name" => "Test Song",
          "artists" => [
            %{"name" => "Artist One"},
            %{"name" => "Artist Two"}
          ],
          "album" => %{"name" => "Test Album"},
          "track_number" => 3,
          "duration_ms" => 240_000,
          "preview_url" => "https://example.com/preview.mp3"
        }
      }

      expect(SpotifyApi, :get_playback_state, fn %Scope{user: ^user}, %{} ->
        {:ok, playback_response}
      end)

      result = TrackReader.get_current_track(broadcaster_id)

      assert {:ok, track_data} = result
      # We don't have internal track ID
      assert track_data.id == nil
      assert track_data.name == "Test Song"
      assert track_data.artist == "Artist One, Artist Two"
      assert track_data.album == "Test Album"
      assert track_data.track_number == 3
      assert track_data.duration_ms == 240_000
      assert track_data.spotify_id == "track_123"
      assert track_data.preview_url == "https://example.com/preview.mp3"
    end

    test "returns error when user not found" do
      broadcaster_id = "nonexistent_broadcaster"

      result = TrackReader.get_current_track(broadcaster_id)

      assert result == {:error, :no_user}
    end

    test "returns error when user has no Spotify connection" do
      user =
        user_fixture(%{
          twitch: %{user_id: "broadcaster456"}
        })

      broadcaster_id = user.twitch.user_id

      result = TrackReader.get_current_track(broadcaster_id)

      assert result == {:error, :no_spotify}
    end

    test "returns error when Spotify API call fails", %{user: user} do
      broadcaster_id = user.twitch.user_id

      expect(SpotifyApi, :get_playback_state, fn %Scope{user: ^user}, %{} ->
        {:error, :api_error}
      end)

      result = TrackReader.get_current_track(broadcaster_id)

      assert result == {:error, :api_error}
    end

    test "returns error when nothing is playing", %{user: user} do
      broadcaster_id = user.twitch.user_id

      playback_response = %{
        "is_playing" => false,
        "item" => %{
          "id" => "track_123",
          "name" => "Test Song"
        }
      }

      expect(SpotifyApi, :get_playback_state, fn %Scope{user: ^user}, %{} ->
        {:ok, playback_response}
      end)

      result = TrackReader.get_current_track(broadcaster_id)

      assert result == {:error, :no_track}
    end

    test "returns error when no item in playback state", %{user: user} do
      broadcaster_id = user.twitch.user_id

      playback_response = %{
        "is_playing" => true,
        "item" => nil
      }

      expect(SpotifyApi, :get_playback_state, fn %Scope{user: ^user}, %{} ->
        {:ok, playback_response}
      end)

      result = TrackReader.get_current_track(broadcaster_id)

      assert result == {:error, :no_track}
    end

    test "handles single artist correctly", %{user: user} do
      broadcaster_id = user.twitch.user_id

      playback_response = %{
        "is_playing" => true,
        "item" => %{
          "id" => "track_123",
          "name" => "Solo Song",
          "artists" => [%{"name" => "Solo Artist"}],
          "album" => %{"name" => "Solo Album"},
          "track_number" => 1,
          "duration_ms" => 180_000,
          "preview_url" => nil
        }
      }

      expect(SpotifyApi, :get_playback_state, fn %Scope{user: ^user}, %{} ->
        {:ok, playback_response}
      end)

      result = TrackReader.get_current_track(broadcaster_id)

      assert {:ok, track_data} = result
      assert track_data.artist == "Solo Artist"
      assert track_data.preview_url == nil
    end

    test "handles malformed artists data", %{user: user} do
      broadcaster_id = user.twitch.user_id

      playback_response = %{
        "is_playing" => true,
        "item" => %{
          "id" => "track_123",
          "name" => "Unknown Artist Song",
          # Malformed artists data
          "artists" => nil,
          "album" => %{"name" => "Unknown Album"},
          "track_number" => 1,
          "duration_ms" => 180_000,
          "preview_url" => nil
        }
      }

      expect(SpotifyApi, :get_playback_state, fn %Scope{user: ^user}, %{} ->
        {:ok, playback_response}
      end)

      result = TrackReader.get_current_track(broadcaster_id)

      assert {:ok, track_data} = result
      assert track_data.artist == "Unknown Artist"
    end

    test "returns error for unexpected playback state format", %{user: user} do
      broadcaster_id = user.twitch.user_id

      # Unexpected/malformed response
      playback_response = %{"unexpected" => "format"}

      expect(SpotifyApi, :get_playback_state, fn %Scope{user: ^user}, %{} ->
        {:ok, playback_response}
      end)

      result = TrackReader.get_current_track(broadcaster_id)

      assert result == {:error, :no_track}
    end
  end
end
