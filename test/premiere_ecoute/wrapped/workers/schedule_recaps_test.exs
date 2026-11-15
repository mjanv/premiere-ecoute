defmodule PremiereEcoute.Wrapped.Workers.ScheduleRecapsTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.Wrapped.WrappedFixtures

  alias PremiereEcoute.Wrapped.Workers.ComputeRecap
  alias PremiereEcoute.Wrapped.Workers.ScheduleRecaps

  setup do
    {:ok, streamer: user_fixture(%{role: :streamer}), viewer: user_fixture(%{twitch: %{user_id: "viewer1"}})}
  end

  describe "perform/1" do
    test "enqueues the viewers without a recap during the campaign", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["8"], voted_at: ~U[2026-06-01 20:00:00Z])

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert perform_job(ScheduleRecaps, %{today: "2026-12-20"}) == :ok

        assert [%Oban.Job{args: args, priority: 9}] = all_enqueued(worker: ComputeRecap)
        assert args == %{"user_id" => viewer.id, "year" => 2026}
      end)
    end

    test "skips the viewers who already have a recap", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["8"], voted_at: ~U[2026-06-01 20:00:00Z])
      recap_fixture(viewer, 2026)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert perform_job(ScheduleRecaps, %{today: "2027-01-31"}) == :ok

        refute_enqueued worker: ComputeRecap
      end)
    end

    test "enqueues nothing outside the campaign", %{streamer: streamer} do
      listened(streamer, 1, ["8"], voted_at: ~U[2026-06-01 20:00:00Z])

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert perform_job(ScheduleRecaps, %{today: "2026-12-13"}) == :ok
        assert perform_job(ScheduleRecaps, %{today: "2027-02-01"}) == :ok

        refute_enqueued worker: ComputeRecap
      end)
    end

    test "enqueues the recaps of a given year", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["8"], voted_at: ~U[2026-06-01 20:00:00Z])

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert perform_job(ScheduleRecaps, %{year: 2027}) == :ok
        refute_enqueued worker: ComputeRecap

        assert perform_job(ScheduleRecaps, %{year: 2026}) == :ok
        assert [%Oban.Job{args: args}] = all_enqueued(worker: ComputeRecap)
        assert args == %{"user_id" => viewer.id, "year" => 2026}
      end)
    end

    test "enqueues nothing when nobody voted" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert perform_job(ScheduleRecaps, %{}) == :ok

        refute_enqueued worker: ComputeRecap
      end)
    end
  end
end
