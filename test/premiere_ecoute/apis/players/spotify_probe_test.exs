defmodule PremiereEcoute.Apis.Players.SpotifyProbeTest do
  use PremiereEcoute.DataCase, async: false

  import ExUnit.CaptureLog

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Apis.Players.SpotifyProbe

  defp playing(id, progress_ms) do
    %PlaybackState{
      is_playing: true,
      progress_ms: progress_ms,
      device: %{name: "Desktop", is_active: true},
      item: %{
        uri: "spotify:track:#{id}",
        name: "Song",
        duration_ms: 180_000,
        artists: [],
        type: :album,
        track_number: nil,
        album: nil
      }
    }
  end

  setup do
    level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: level) end)
  end

  describe "perform/1" do
    test "pauses then resumes the current track and logs each step" do
      user = user_fixture(%{spotify: %{}})
      state = playing("abc123", 42_000)

      Mox.expect(SpotifyApi, :get_playback_state, 2, fn _scope, _default -> {:ok, state} end)
      Mox.expect(SpotifyApi, :pause_playback, fn _scope -> {:ok, :success} end)
      Mox.expect(SpotifyApi, :start_resume_playback, fn _scope, ^state -> {:ok, "spotify:track:abc123"} end)

      log = capture_log(fn -> assert :ok = perform_job(SpotifyProbe, %{user_id: user.id, step_delay_ms: 0}) end)

      assert log =~ "[SpotifyProbe] user=#{user.id} step=playing result=ok"
      assert log =~ "[SpotifyProbe] user=#{user.id} step=pause result=ok"
      assert log =~ "[SpotifyProbe] user=#{user.id} step=play result=ok"
      assert log =~ "[SpotifyProbe] user=#{user.id} step=verify result=ok"
    end

    test "logs the reason of a refused command and still runs the remaining steps" do
      user = user_fixture(%{spotify: %{}})
      state = playing("abc123", 42_000)

      Mox.expect(SpotifyApi, :get_playback_state, 2, fn _scope, _default -> {:ok, state} end)
      Mox.expect(SpotifyApi, :pause_playback, fn _scope -> {:error, "Spotify playback failed"} end)
      Mox.expect(SpotifyApi, :start_resume_playback, fn _scope, ^state -> {:ok, "spotify:track:abc123"} end)

      log = capture_log(fn -> assert :ok = perform_job(SpotifyProbe, %{user_id: user.id, step_delay_ms: 0}) end)

      assert log =~ ~s([SpotifyProbe] user=#{user.id} step=pause result=error reason="\\"Spotify playback failed\\"")
      assert log =~ "step=play result=ok"
    end

    test "snoozes while nothing is playing, then gives up after the deadline" do
      user = user_fixture(%{spotify: %{}})
      idle = %PlaybackState{playing("abc123", 0) | is_playing: false}

      Mox.stub(SpotifyApi, :get_playback_state, fn _scope, _default -> {:ok, idle} end)

      recent = DateTime.utc_now() |> DateTime.to_iso8601()
      assert {:snooze, 30} = perform_job(SpotifyProbe, %{user_id: user.id, started_at: recent})

      old = DateTime.utc_now() |> DateTime.add(-9 * 60, :second) |> DateTime.to_iso8601()

      log = capture_log(fn -> assert :ok = perform_job(SpotifyProbe, %{user_id: user.id, started_at: old}) end)

      assert log =~ "[SpotifyProbe] user=#{user.id} step=playing result=error"
    end
  end

  describe "email" do
    defp run_probe(user, pause_result, play_result) do
      state = playing("abc123", 42_000)

      Mox.expect(SpotifyApi, :get_playback_state, 2, fn _scope, _default -> {:ok, state} end)
      Mox.expect(SpotifyApi, :pause_playback, fn _scope -> pause_result end)
      Mox.expect(SpotifyApi, :start_resume_playback, fn _scope, ^state -> play_result end)

      capture_log(fn -> assert :ok = perform_job(SpotifyProbe, %{user_id: user.id, step_delay_ms: 0}) end)
    end

    test "is sent when pause and play both work" do
      user = user_fixture(%{spotify: %{}})

      run_probe(user, {:ok, :success}, {:ok, "spotify:track:abc123"})

      assert_email_sent(subject: "Spotify probe OK for #{user.username}", to: {"Maxime Janvier", "maxime.janvier@gmail.com"})
    end

    test "is not sent when pause is refused" do
      user = user_fixture(%{spotify: %{}})

      run_probe(user, {:error, "Spotify playback failed"}, {:ok, "spotify:track:abc123"})

      refute_email_sent()
    end

    test "is not sent when play is refused" do
      user = user_fixture(%{spotify: %{}})

      run_probe(user, {:ok, :success}, {:error, "Spotify playback failed"})

      refute_email_sent()
    end
  end
end
