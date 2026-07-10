defmodule Worker do
  use PremiereEcouteCore.Worker

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    {:ok, args}
  end
end

defmodule PremiereEcouteCore.WorkerTest do
  use PremiereEcoute.DataCase, async: true

  describe "Worker" do
    test "can start a background job" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, args} = perform_job(Worker, %{id: 123})

        assert args == %{"id" => 123}
      end)
    end
  end

  describe "start/1" do
    test "can queue a background job" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.start(%{id: 234})

        assert_enqueued worker: Worker, args: %{"id" => 234}
      end)
    end

    test "can start multiples background job" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.start([%{id: 234}, %{id: 567}])

        assert_enqueued worker: Worker, args: %{"id" => 234}
        assert_enqueued worker: Worker, args: %{"id" => 567}
      end)
    end
  end

  describe "now/1" do
    test "can queue a background job" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.now(%{id: 234})

        assert_enqueued worker: Worker, args: %{"id" => 234}
      end)
    end

    test "can start multiples background job" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.now([%{id: 234}, %{id: 567}])

        assert_enqueued worker: Worker, args: %{"id" => 234}
        assert_enqueued worker: Worker, args: %{"id" => 567}
      end)
    end
  end

  describe "in_seconds/1" do
    test "can queue a background job" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.in_seconds(%{id: 234}, 60 * 60)

        assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      end)
    end

    test "can queue multiples background jobs" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.in_seconds([%{id: 234}, %{id: 567}], 60 * 60)

        assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        assert_enqueued worker: Worker, args: %{"id" => 567}, scheduled_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      end)
    end
  end

  describe "in_minutes/1" do
    test "can queue a background job" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.in_minutes(%{id: 234}, 60)

        assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: DateTime.add(DateTime.utc_now(), 60, :minute)
      end)
    end

    test "can queue multiples background jobs" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.in_minutes([%{id: 234}, %{id: 567}], 60)

        assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: DateTime.add(DateTime.utc_now(), 60, :minute)
        assert_enqueued worker: Worker, args: %{"id" => 567}, scheduled_at: DateTime.add(DateTime.utc_now(), 60, :minute)
      end)
    end
  end

  describe "in_hours/1" do
    test "can queue a background job" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.in_hours(%{id: 234}, 1)

        assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: DateTime.add(DateTime.utc_now(), 1, :hour)
      end)
    end

    test "can queue multiples background jobs" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.in_hours([%{id: 234}, %{id: 567}], 1)

        assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: DateTime.add(DateTime.utc_now(), 1, :hour)
        assert_enqueued worker: Worker, args: %{"id" => 567}, scheduled_at: DateTime.add(DateTime.utc_now(), 1, :hour)
      end)
    end
  end

  describe "in_days/1" do
    test "can queue a background job" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.in_days(%{id: 234}, 1)

        assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: DateTime.add(DateTime.utc_now(), 1, :day)
      end)
    end

    test "can queue multiples background jobs" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.in_days([%{id: 234}, %{id: 567}], 1)

        assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: DateTime.add(DateTime.utc_now(), 1, :day)
        assert_enqueued worker: Worker, args: %{"id" => 567}, scheduled_at: DateTime.add(DateTime.utc_now(), 1, :day)
      end)
    end
  end

  describe "in_weeks/1" do
    test "can queue a background job" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.in_weeks(%{id: 234}, 1)

        assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: DateTime.add(DateTime.utc_now(), 7, :day)
      end)
    end

    test "can queue multiples background jobs" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.in_weeks([%{id: 234}, %{id: 567}], 1)

        assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: DateTime.add(DateTime.utc_now(), 7, :day)
        assert_enqueued worker: Worker, args: %{"id" => 567}, scheduled_at: DateTime.add(DateTime.utc_now(), 7, :day)
      end)
    end
  end

  describe "at/1" do
    test "can queue a background job" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        in_an_hour = DateTime.add(DateTime.utc_now(), 60, :minute)
        Worker.at(%{id: 234}, in_an_hour)

        assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: in_an_hour
      end)
    end

    test "can queue multiple background jobs" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        in_an_hour = DateTime.add(DateTime.utc_now(), 60, :minute)
        Worker.at([%{id: 234}, %{id: 567}], in_an_hour)

        assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: in_an_hour
        assert_enqueued worker: Worker, args: %{"id" => 567}, scheduled_at: in_an_hour
      end)
    end
  end

  describe "cancel_all/0" do
    test "cancels all scheduled jobs for the worker" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.in_hours(%{id: 234}, 1)
        Worker.in_hours(%{id: 567}, 1)

        assert {:ok, 2} = Worker.cancel_all()

        refute_enqueued worker: Worker, args: %{"id" => 234}
        refute_enqueued worker: Worker, args: %{"id" => 567}
      end)
    end
  end

  describe "cancel_all/1" do
    test "cancels only jobs matching the given args" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.in_hours(%{id: 234}, 1)
        Worker.in_hours(%{id: 567}, 1)

        assert {:ok, 1} = Worker.cancel_all(id: 234)

        refute_enqueued worker: Worker, args: %{"id" => 234}
        assert_enqueued worker: Worker, args: %{"id" => 567}
      end)
    end

    test "matches on multiple args" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.in_hours(%{id: 234, action: "poll"}, 1)
        Worker.in_hours(%{id: 234, action: "cleanup"}, 1)

        assert {:ok, 1} = Worker.cancel_all(id: 234, action: "poll")

        refute_enqueued worker: Worker, args: %{"id" => 234, "action" => "poll"}
        assert_enqueued worker: Worker, args: %{"id" => 234, "action" => "cleanup"}
      end)
    end

    test "returns {:ok, 0} when nothing matches" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.in_hours(%{id: 234}, 1)

        assert {:ok, 0} = Worker.cancel_all(id: 999)

        assert_enqueued worker: Worker, args: %{"id" => 234}
      end)
    end
  end

  describe "next_in?/0" do
    test "returns the scheduled_at of the next scheduled job" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        in_an_hour = DateTime.add(DateTime.utc_now(), 60, :minute)
        in_two_hours = DateTime.add(DateTime.utc_now(), 120, :minute)

        Worker.at(%{id: 234}, in_two_hours)
        Worker.at(%{id: 567}, in_an_hour)

        assert DateTime.diff(Worker.next_in?(), in_an_hour, :second) == 0
      end)
    end

    test "returns nil when no job is scheduled" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert Worker.next_in?() == nil
      end)
    end
  end

  describe "next_in?/1" do
    test "returns the scheduled_at of the next scheduled job matching the given args" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        in_an_hour = DateTime.add(DateTime.utc_now(), 60, :minute)
        in_two_hours = DateTime.add(DateTime.utc_now(), 120, :minute)

        Worker.at(%{id: 234}, in_an_hour)
        Worker.at(%{id: 567}, in_two_hours)

        assert DateTime.diff(Worker.next_in?(id: 567), in_two_hours, :second) == 0
      end)
    end

    test "returns nil when no job matches the given args" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        Worker.in_hours(%{id: 234}, 1)

        assert Worker.next_in?(id: 999) == nil
      end)
    end
  end
end
