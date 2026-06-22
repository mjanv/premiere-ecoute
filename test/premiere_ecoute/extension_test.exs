defmodule PremiereEcoute.ExtensionTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Extension
  alias PremiereEcouteCore.Cache

  setup_all do
    start_supervised({Cache, name: :playback})
    :ok
  end

  describe "get_current_track/1" do
    setup do
      Cache.clear(:playback)
      stub(SpotifyApi, :get_playback_state, fn _scope, _state -> {:ok, PlaybackState.default()} end)
      :ok
    end

    test "successfully gets current track via TrackReader delegation" do
      user =
        user_fixture(%{
          twitch: %{user_id: "broadcaster123"},
          spotify: %{user_id: "spotify_user_123"}
        })

      broadcaster_id = user.twitch.user_id

      expect(SpotifyApi, :get_playback_state, fn _scope, %PlaybackState{} ->
        {:ok,
         %PlaybackState{
           is_playing: true,
           progress_ms: 0,
           item: %{
             uri: "spotify:track:track_123",
             name: "Test Song",
             duration_ms: 180_000,
             artists: [%{name: "Test Artist"}],
             type: :album,
             track_number: nil,
             album: nil
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
end
