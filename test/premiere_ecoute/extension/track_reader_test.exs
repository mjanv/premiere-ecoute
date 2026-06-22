defmodule PremiereEcoute.Extension.TrackReaderTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Extension.TrackReader
  alias PremiereEcouteCore.Cache

  setup_all do
    start_supervised({Cache, name: :playback})

    :ok
  end

  describe "get_current_track/1" do
    setup do
      Cache.clear(:playback)

      user =
        user_fixture(%{
          twitch: %{user_id: "broadcaster123"},
          spotify: %{user_id: "spotify_user_123"}
        })

      {:ok, user: user}
    end

    test "returns current playing track successfully", %{user: user} do
      broadcaster_id = user.twitch.user_id

      playback_response = %PlaybackState{
        is_playing: true,
        progress_ms: 60_000,
        device: %{name: "Device", is_active: true},
        item: %{
          uri: "spotify:track:track_123",
          name: "Test Song",
          duration_ms: 240_000,
          artists: [%{name: "Artist One"}, %{name: "Artist Two"}],
          type: :album,
          track_number: nil,
          album: nil
        }
      }

      expect(SpotifyApi, :get_playback_state, fn %Scope{user: ^user}, %PlaybackState{} ->
        {:ok, playback_response}
      end)

      result = TrackReader.get_current_track(broadcaster_id)

      assert {:ok, track_data} = result
      assert track_data.id == nil
      assert track_data.name == "Test Song"
      assert track_data.artist == "Artist One, Artist Two"
      assert track_data.duration_ms == 240_000
      assert track_data.spotify_id == "track_123"
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

      expect(SpotifyApi, :get_playback_state, fn %Scope{user: ^user}, %PlaybackState{} ->
        {:error, :api_error}
      end)

      result = TrackReader.get_current_track(broadcaster_id)

      assert result == {:error, :api_error}
    end

    test "returns error when nothing is playing", %{user: user} do
      broadcaster_id = user.twitch.user_id

      expect(SpotifyApi, :get_playback_state, fn %Scope{user: ^user}, %PlaybackState{} ->
        {:ok,
         %PlaybackState{
           is_playing: false,
           item: %{
             uri: "spotify:track:123",
             name: "Song",
             duration_ms: 1,
             artists: [],
             type: :album,
             track_number: nil,
             album: nil
           }
         }}
      end)

      result = TrackReader.get_current_track(broadcaster_id)

      assert result == {:error, :no_track}
    end

    test "returns error when no item in playback state", %{user: user} do
      broadcaster_id = user.twitch.user_id

      expect(SpotifyApi, :get_playback_state, fn %Scope{user: ^user}, %PlaybackState{} ->
        {:ok, %PlaybackState{is_playing: true, item: nil}}
      end)

      result = TrackReader.get_current_track(broadcaster_id)

      assert result == {:error, :no_track}
    end

    test "handles single artist correctly", %{user: user} do
      broadcaster_id = user.twitch.user_id

      expect(SpotifyApi, :get_playback_state, fn %Scope{user: ^user}, %PlaybackState{} ->
        {:ok,
         %PlaybackState{
           is_playing: true,
           progress_ms: 0,
           item: %{
             uri: "spotify:track:track_123",
             name: "Solo Song",
             duration_ms: 180_000,
             artists: [%{name: "Solo Artist"}],
             type: :album,
             track_number: nil,
             album: nil
           }
         }}
      end)

      result = TrackReader.get_current_track(broadcaster_id)

      assert {:ok, track_data} = result
      assert track_data.artist == "Solo Artist"
    end

    test "handles malformed artists data", %{user: user} do
      broadcaster_id = user.twitch.user_id

      expect(SpotifyApi, :get_playback_state, fn %Scope{user: ^user}, %PlaybackState{} ->
        {:ok,
         %PlaybackState{
           is_playing: true,
           progress_ms: 0,
           item: %{
             uri: "spotify:track:track_123",
             name: "Unknown Artist Song",
             duration_ms: 180_000,
             artists: [],
             type: :album,
             track_number: nil,
             album: nil
           }
         }}
      end)

      result = TrackReader.get_current_track(broadcaster_id)

      assert {:ok, track_data} = result
      assert track_data.artist == ""
    end

    test "returns error for unexpected playback state format", %{user: user} do
      broadcaster_id = user.twitch.user_id

      expect(SpotifyApi, :get_playback_state, fn %Scope{user: ^user}, %PlaybackState{} ->
        {:ok, PlaybackState.default()}
      end)

      result = TrackReader.get_current_track(broadcaster_id)

      assert result == {:error, :no_track}
    end
  end
end
