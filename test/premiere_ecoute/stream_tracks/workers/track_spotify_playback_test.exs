defmodule PremiereEcoute.StreamTracks.Workers.TrackSpotifyPlaybackTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.StreamTracks
  alias PremiereEcoute.StreamTracks.Workers.TrackSpotifyPlayback

  describe "perform/1" do
    test "stores a track when feature is enabled and playback is active" do
      user = user_fixture()

      # Enable stream tracking for the user
      user = enable_stream_tracking(user)

      # Mock Spotify API to return playback state with a track
      Mox.expect(SpotifyApi, :get_playback_state, fn _scope, _default ->
        {:ok,
         %{
           "is_playing" => true,
           "item" => %{
             "id" => "spotify:track:123",
             "name" => "Test Song",
             "artists" => [%{"name" => "Test Artist"}],
             "album" => %{"name" => "Test Album"},
             "duration_ms" => 180_000
           }
         }}
      end)

      # Perform the job
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(TrackSpotifyPlayback, %{user_id: user.id})

        # Verify next job was scheduled
        assert_enqueued worker: TrackSpotifyPlayback,
                        args: %{user_id: user.id},
                        scheduled_at: {DateTime.utc_now() |> DateTime.add(60, :second), delta: 5}
      end)

      # Verify track was stored
      tracks = StreamTracks.get_tracks(user.id, Date.utc_today())
      assert length(tracks) == 1
      assert Enum.at(tracks, 0).provider_id == "spotify:track:123"
    end

    test "does nothing when feature is disabled" do
      user = user_fixture()

      # Don't mock Spotify API - it shouldn't be called

      # Perform the job without enabling the feature
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(TrackSpotifyPlayback, %{user_id: user.id})
      end)

      # Verify no tracks were stored
      tracks = StreamTracks.get_tracks(user.id, Date.utc_today())
      assert tracks == []
    end
  end

  defp enable_stream_tracking(user) do
    {:ok, user} =
      PremiereEcoute.Accounts.User.edit_user_profile(user, %{
        stream_track_settings: %{
          enabled: true,
          retention_days: 7,
          visibility: :public
        }
      })

    user
  end
end
