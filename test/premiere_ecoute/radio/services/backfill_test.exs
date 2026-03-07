defmodule PremiereEcoute.Radio.Services.BackfillTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Radio.RadioTrack
  alias PremiereEcoute.Radio.Services.Backfill
  alias PremiereEcoute.Radio.Workers.LinkProviderTrack

  defp track_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        provider_ids: %{spotify: "1pKYYY0dkg23sQQXi0Q5zN"},
        name: "Around the World",
        artist: "Daft Punk",
        album: "Homework",
        duration_ms: 429_533,
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      },
      overrides
    )
  end

  describe "insert_track/3" do
    test "inserts the track and returns it" do
      user = user_fixture()

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, track} = Backfill.insert_track(user.id, "spotify", track_attrs())
        assert track.name == "Around the World"
        assert track.provider_ids == %{spotify: "1pKYYY0dkg23sQQXi0Q5zN"}
      end)
    end

    test "schedules LinkProviderTrack 15 seconds after insert" do
      user = user_fixture()

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _track} = Backfill.insert_track(user.id, "spotify", track_attrs())

        assert_enqueued worker: LinkProviderTrack,
                        scheduled_at: {DateTime.utc_now() |> DateTime.add(15, :second), delta: 5}
      end)
    end

    test "returns consecutive_duplicate error without scheduling a job" do
      user = user_fixture()
      attrs = track_attrs()

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _} = Backfill.insert_track(user.id, "spotify", attrs)
        assert {:error, :consecutive_duplicate} = Backfill.insert_track(user.id, "spotify", attrs)

        # Only one job scheduled — for the first insert
        assert [_] = all_enqueued(worker: LinkProviderTrack)
      end)
    end
  end

  describe "backward_fill/1" do
    test "schedules one LinkProviderTrack job per existing track, staggered by index" do
      user = user_fixture()

      # Use RadioTrack.insert directly to seed data without scheduling any jobs
      {:ok, _} = RadioTrack.insert(user.id, track_attrs())
      {:ok, _} = RadioTrack.insert(user.id, track_attrs(%{provider_ids: %{spotify: "other"}}))

      Oban.Testing.with_testing_mode(:manual, fn ->
        :ok = Backfill.backward_fill(:spotify)
        jobs = all_enqueued(worker: LinkProviderTrack)
        assert length(jobs) == 2
      end)
    end

    test "returns :ok" do
      user = user_fixture()
      {:ok, _} = RadioTrack.insert(user.id, track_attrs())

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = Backfill.backward_fill(:spotify)
      end)
    end

    test "returns :ok when there are no tracks" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = Backfill.backward_fill(:spotify)
      end)
    end
  end
end
