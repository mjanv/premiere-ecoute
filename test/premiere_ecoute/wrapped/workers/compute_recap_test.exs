defmodule PremiereEcoute.Wrapped.Workers.ComputeRecapTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.Wrapped.WrappedFixtures

  alias PremiereEcoute.Wrapped.Recap
  alias PremiereEcoute.Wrapped.Workers.ComputeRecap

  @year Date.utc_today().year

  describe "perform/1" do
    test "computes and stores the recap of the user" do
      stub_covers()
      viewer = user_fixture(%{twitch: %{user_id: "viewer1"}})
      streamer = user_fixture(%{role: :streamer})
      for n <- 1..3, do: listened(streamer, n, ["8"])

      assert perform_job(ComputeRecap, %{user_id: viewer.id, year: @year}) == :ok

      assert %Recap{cards: [_ | _]} = Recap.current(viewer, @year)
    end

    test "does nothing for an unknown user" do
      assert perform_job(ComputeRecap, %{user_id: -1, year: @year}) == :ok

      assert Repo.aggregate(Recap, :count) == 0
    end
  end

  describe "job" do
    test "runs in the wrapped queue, three times at most" do
      assert %{queue: "wrapped", max_attempts: 3} = ComputeRecap.new(%{user_id: 1, year: @year}).changes
    end

    test "is unique per user and per year while it is waiting" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, %Oban.Job{conflict?: false}} = ComputeRecap.now(%{user_id: 1, year: @year})
        assert {:ok, %Oban.Job{conflict?: true}} = ComputeRecap.now(%{user_id: 1, year: @year})
        assert {:ok, %Oban.Job{conflict?: false}} = ComputeRecap.now(%{user_id: 1, year: @year - 1})
        assert {:ok, %Oban.Job{conflict?: false}} = ComputeRecap.now(%{user_id: 2, year: @year})

        assert length(all_enqueued(worker: ComputeRecap)) == 3
      end)
    end
  end
end
