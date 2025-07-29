defmodule Worker do
  use PremiereEcoute.Core.Worker

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    {:ok, args}
  end
end

defmodule PremiereEcoute.Core.WorkerTest do
  use PremiereEcoute.DataCase

  describe "Worker" do
    test "can start a background job" do
      {:ok, args} = perform_job(Worker, %{id: 123})

      assert args == %{"id" => 123}
    end
  end

  describe "start/1" do
    test "can queue a background job" do
      Worker.start(%{id: 234})

      assert_enqueued worker: Worker, args: %{"id" => 234}
    end
  end

  describe "in_seconds/1" do
    test "can queue a background job" do
      Worker.in_seconds(%{id: 234}, 60 * 60)

      assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    end
  end

  describe "in_minutes/1" do
    test "can queue a background job" do
      Worker.in_minutes(%{id: 234}, 60)

      assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: DateTime.add(DateTime.utc_now(), 60, :minute)
    end
  end

  describe "in_hours/1" do
    test "can queue a background job" do
      Worker.in_hours(%{id: 234}, 1)

      assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: DateTime.add(DateTime.utc_now(), 1, :hour)
    end
  end

  describe "in_days/1" do
    test "can queue a background job" do
      Worker.in_days(%{id: 234}, 1)

      assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: DateTime.add(DateTime.utc_now(), 1, :day)
    end
  end

  describe "in_weeks/1" do
    test "can queue a background job" do
      Worker.in_weeks(%{id: 234}, 1)

      assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: DateTime.add(DateTime.utc_now(), 7, :day)
    end
  end

  describe "at/1" do
    test "can queue a background job" do
      in_an_hour = DateTime.add(DateTime.utc_now(), 60, :minute)
      Worker.at(%{id: 234}, in_an_hour)

      assert_enqueued worker: Worker, args: %{"id" => 234}, scheduled_at: in_an_hour
    end
  end
end
