defmodule Worker do
  use PremiereEcouteCore.Worker

  require Logger

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
end
