defmodule PremiereEcoute.Radio.Workers.TrackSpotifyPlaybackTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Radio
  alias PremiereEcoute.Radio.Workers.TrackSpotifyPlayback
  alias PremiereEcouteCore.Cache

  setup_all do
    start_supervised({Cache, name: :playback})
    :ok
  end

  setup do
    Cache.clear(:playback)
    :ok
  end

  defp playing(id, duration_ms, progress_ms \\ 0) do
    %PlaybackState{
      is_playing: true,
      progress_ms: progress_ms,
      item: %{
        uri: "spotify:track:#{id}",
        name: "Test Song",
        duration_ms: duration_ms,
        artists: [%{name: "Test Artist"}],
        type: :album,
        track_number: nil,
        album: nil
      }
    }
  end

  describe "perform/1" do
    test "stores a track when feature is enabled and playback is active" do
      user = user_fixture() |> enable_radio_tracking()

      Mox.expect(SpotifyApi, :get_playback_state, fn _scope, _default ->
        {:ok, playing("abc123", 180_000)}
      end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(TrackSpotifyPlayback, %{user_id: user.id})

        assert_enqueued worker: TrackSpotifyPlayback,
                        args: %{user_id: user.id},
                        scheduled_at: {DateTime.utc_now() |> DateTime.add(210, :second), delta: 5}
      end)

      tracks = Radio.get_tracks(user.id, Date.utc_today())
      assert length(tracks) == 1
      assert Enum.at(tracks, 0).provider_ids == %{spotify: "abc123"}
    end

    test "started_at is calculated from progress_ms when available" do
      user = user_fixture() |> enable_radio_tracking()
      progress_ms = 30_000

      Mox.expect(SpotifyApi, :get_playback_state, fn _scope, _default ->
        {:ok, playing("def456", 180_000, progress_ms)}
      end)

      before = DateTime.utc_now()

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(TrackSpotifyPlayback, %{user_id: user.id})
      end)

      [track] = Radio.get_tracks(user.id, Date.utc_today())
      expected_started_at = DateTime.add(before, -progress_ms, :millisecond)
      assert DateTime.diff(track.started_at, expected_started_at, :second) in -2..2
    end

    test "started_at falls back to detection time when progress_ms is nil" do
      user = user_fixture() |> enable_radio_tracking()

      Mox.expect(SpotifyApi, :get_playback_state, fn _scope, _default ->
        {:ok,
         %PlaybackState{
           is_playing: true,
           progress_ms: nil,
           item: %{
             uri: "spotify:track:ghi789",
             name: "Test Song",
             duration_ms: 180_000,
             artists: [%{name: "Test Artist"}],
             type: :album,
             track_number: nil,
             album: nil
           }
         }}
      end)

      before = DateTime.utc_now()

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(TrackSpotifyPlayback, %{user_id: user.id})
      end)

      [track] = Radio.get_tracks(user.id, Date.utc_today())
      assert DateTime.diff(track.started_at, before, :second) in -2..2
    end

    test "next poll is scheduled at remaining track time + 30s when progress_ms is available" do
      user = user_fixture() |> enable_radio_tracking()
      duration_ms = 180_000
      progress_ms = 30_000
      remaining_ms = duration_ms - progress_ms
      expected_delay_s = div(remaining_ms + 30_000, 1000)

      Mox.expect(SpotifyApi, :get_playback_state, fn _scope, _default ->
        {:ok, playing("jkl012", duration_ms, progress_ms)}
      end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(TrackSpotifyPlayback, %{user_id: user.id})

        assert_enqueued worker: TrackSpotifyPlayback,
                        args: %{user_id: user.id},
                        scheduled_at: {DateTime.utc_now() |> DateTime.add(expected_delay_s, :second), delta: 5}
      end)
    end

    test "next poll falls back to 60s when progress_ms is nil" do
      user = user_fixture() |> enable_radio_tracking()

      Mox.expect(SpotifyApi, :get_playback_state, fn _scope, _default ->
        {:ok,
         %PlaybackState{
           is_playing: true,
           progress_ms: nil,
           item: %{
             uri: "spotify:track:mno345",
             name: "Test Song",
             duration_ms: 180_000,
             artists: [%{name: "Test Artist"}],
             type: :album,
             track_number: nil,
             album: nil
           }
         }}
      end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(TrackSpotifyPlayback, %{user_id: user.id})

        assert_enqueued worker: TrackSpotifyPlayback,
                        args: %{user_id: user.id},
                        scheduled_at: {DateTime.utc_now() |> DateTime.add(60, :second), delta: 5}
      end)
    end

    test "backs off 5 minutes on rate limit" do
      user = user_fixture() |> enable_radio_tracking()

      Mox.expect(SpotifyApi, :get_playback_state, fn _scope, _default ->
        {:error, "Spotify rate limit exceeded"}
      end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(TrackSpotifyPlayback, %{user_id: user.id})

        assert_enqueued worker: TrackSpotifyPlayback,
                        args: %{user_id: user.id},
                        scheduled_at: {DateTime.utc_now() |> DateTime.add(300, :second), delta: 5}
      end)

      assert Radio.get_tracks(user.id, Date.utc_today()) == []
    end

    test "reschedules 30s later on playback error to keep the loop alive" do
      user = user_fixture() |> enable_radio_tracking()

      Mox.expect(SpotifyApi, :get_playback_state, fn _scope, _default ->
        {:error, "Spotify playback state failed"}
      end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(TrackSpotifyPlayback, %{user_id: user.id})

        assert_enqueued worker: TrackSpotifyPlayback,
                        args: %{user_id: user.id},
                        scheduled_at: {DateTime.utc_now() |> DateTime.add(30, :second), delta: 5}
      end)

      assert Radio.get_tracks(user.id, Date.utc_today()) == []
    end

    test "does nothing when feature is disabled" do
      user = user_fixture()

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(TrackSpotifyPlayback, %{user_id: user.id})
      end)

      assert Radio.get_tracks(user.id, Date.utc_today()) == []
    end
  end

  defp enable_radio_tracking(user) do
    {:ok, user} =
      User.edit_user_profile(user, %{
        radio_settings: %{enabled: true, retention_days: 7, visibility: :public}
      })

    user
  end
end
