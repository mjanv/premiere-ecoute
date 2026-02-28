defmodule PremiereEcoute.Radio.Workers.TrackSpotifyPlaybackTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Radio
  alias PremiereEcoute.Radio.Workers.TrackSpotifyPlayback

  describe "perform/1" do
    test "stores a track when feature is enabled and playback is active" do
      user = user_fixture()
      user = enable_radio_tracking(user)

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

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(TrackSpotifyPlayback, %{user_id: user.id})

        assert_enqueued worker: TrackSpotifyPlayback,
                        args: %{user_id: user.id},
                        scheduled_at: {DateTime.utc_now() |> DateTime.add(60, :second), delta: 5}
      end)

      tracks = Radio.get_tracks(user.id, Date.utc_today())
      assert length(tracks) == 1
      assert Enum.at(tracks, 0).provider_ids == %{spotify: "spotify:track:123"}
    end

    test "started_at is calculated from progress_ms when available" do
      user = user_fixture()
      user = enable_radio_tracking(user)
      progress_ms = 30_000

      Mox.expect(SpotifyApi, :get_playback_state, fn _scope, _default ->
        {:ok,
         %{
           "is_playing" => true,
           "progress_ms" => progress_ms,
           "item" => %{
             "id" => "spotify:track:456",
             "name" => "Test Song",
             "artists" => [%{"name" => "Test Artist"}],
             "album" => %{"name" => "Test Album"},
             "duration_ms" => 180_000
           }
         }}
      end)

      before = DateTime.utc_now()

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(TrackSpotifyPlayback, %{user_id: user.id})
      end)

      [track] = Radio.get_tracks(user.id, Date.utc_today())
      expected_started_at = DateTime.add(before, -progress_ms, :millisecond)
      assert DateTime.diff(track.started_at, expected_started_at, :second) in -2..2
    end

    test "started_at falls back to detection time when progress_ms is absent" do
      user = user_fixture()
      user = enable_radio_tracking(user)

      Mox.expect(SpotifyApi, :get_playback_state, fn _scope, _default ->
        {:ok,
         %{
           "is_playing" => true,
           "item" => %{
             "id" => "spotify:track:789",
             "name" => "Test Song",
             "artists" => [%{"name" => "Test Artist"}],
             "album" => %{"name" => "Test Album"},
             "duration_ms" => 180_000
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
      user = user_fixture()
      user = enable_radio_tracking(user)
      duration_ms = 180_000
      progress_ms = 30_000
      remaining_ms = duration_ms - progress_ms

      Mox.expect(SpotifyApi, :get_playback_state, fn _scope, _default ->
        {:ok,
         %{
           "is_playing" => true,
           "progress_ms" => progress_ms,
           "item" => %{
             "id" => "spotify:track:abc",
             "name" => "Test Song",
             "artists" => [%{"name" => "Test Artist"}],
             "album" => %{"name" => "Test Album"},
             "duration_ms" => duration_ms
           }
         }}
      end)

      expected_delay_s = div(remaining_ms + 30_000, 1000)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(TrackSpotifyPlayback, %{user_id: user.id})

        assert_enqueued worker: TrackSpotifyPlayback,
                        args: %{user_id: user.id},
                        scheduled_at: {DateTime.utc_now() |> DateTime.add(expected_delay_s, :second), delta: 5}
      end)
    end

    test "next poll falls back to 60s when progress_ms is absent" do
      user = user_fixture()
      user = enable_radio_tracking(user)

      Mox.expect(SpotifyApi, :get_playback_state, fn _scope, _default ->
        {:ok,
         %{
           "is_playing" => true,
           "item" => %{
             "id" => "spotify:track:def",
             "name" => "Test Song",
             "artists" => [%{"name" => "Test Artist"}],
             "album" => %{"name" => "Test Album"},
             "duration_ms" => 180_000
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

    test "does nothing when feature is disabled" do
      user = user_fixture()

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(TrackSpotifyPlayback, %{user_id: user.id})
      end)

      tracks = Radio.get_tracks(user.id, Date.utc_today())
      assert tracks == []
    end
  end

  defp enable_radio_tracking(user) do
    {:ok, user} =
      User.edit_user_profile(user, %{
        radio_settings: %{
          enabled: true,
          retention_days: 7,
          visibility: :public
        }
      })

    user
  end
end
