defmodule PremiereEcoute.Playlists.Automations.Services.AutomationSchedulingTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Playlists.Automations.Automation
  alias PremiereEcoute.Playlists.Automations.Services.AutomationScheduling
  alias PremiereEcoute.Playlists.Automations.Workers.AutomationRunWorker

  defp insert_automation(user, attrs) do
    {:ok, a} = Automation.insert(user, attrs)
    a
  end

  describe "next_run_at/1" do
    test "returns a future datetime for a valid cron expression" do
      result = AutomationScheduling.next_run_at("0 9 * * *")

      assert %DateTime{} = result
      assert DateTime.compare(result, DateTime.utc_now()) == :gt
    end

    test "computes the correct next minute for a minutely expression" do
      now = NaiveDateTime.utc_now()
      result = AutomationScheduling.next_run_at("* * * * *")

      # Next run should be within the next 2 minutes
      diff = DateTime.diff(result, DateTime.from_naive!(now, "Etc/UTC"), :second)
      assert diff >= 0 and diff <= 120
    end
  end

  describe "schedule/1 (manual)" do
    test "enqueues an available job for a manual automation" do
      user = user_fixture()
      automation = insert_automation(user, %{name: "M", schedule_type: :manual})

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, _job} = AutomationScheduling.schedule(automation)
        assert_enqueued worker: AutomationRunWorker, args: %{"automation_id" => automation.id}
      end)
    end
  end

  describe "schedule/2 (once)" do
    test "enqueues a scheduled job at the given datetime" do
      user = user_fixture()
      automation = insert_automation(user, %{name: "O", schedule_type: :once})
      at = DateTime.add(DateTime.utc_now(), 3600, :second)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, _job} = AutomationScheduling.schedule(automation, at)
        assert_enqueued worker: AutomationRunWorker, args: %{"automation_id" => automation.id}
      end)
    end
  end

  describe "schedule_next/1 (recurring)" do
    test "enqueues a future job based on cron expression" do
      user = user_fixture()

      automation =
        insert_automation(user, %{
          name: "R",
          schedule_type: :recurring,
          cron_expression: "0 9 * * *"
        })

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, job} = AutomationScheduling.schedule_next(automation)
        assert DateTime.compare(job.scheduled_at, DateTime.utc_now()) == :gt
        assert_enqueued worker: AutomationRunWorker, args: %{"automation_id" => automation.id}
      end)
    end
  end

  describe "cancel/1" do
    test "cancels pending jobs for the automation" do
      user = user_fixture()
      automation = insert_automation(user, %{name: "R", schedule_type: :recurring, cron_expression: "0 9 * * *"})

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _} = AutomationScheduling.schedule_next(automation)
        assert length(all_enqueued(worker: AutomationRunWorker)) == 1

        AutomationScheduling.cancel(automation)
        assert all_enqueued(worker: AutomationRunWorker) == []
      end)
    end

    test "does not cancel jobs for other automations" do
      user = user_fixture()
      a1 = insert_automation(user, %{name: "A1", schedule_type: :recurring, cron_expression: "0 9 * * *"})
      a2 = insert_automation(user, %{name: "A2", schedule_type: :recurring, cron_expression: "0 9 * * *"})

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _} = AutomationScheduling.schedule_next(a1)
        {:ok, _} = AutomationScheduling.schedule_next(a2)

        AutomationScheduling.cancel(a1)

        jobs = all_enqueued(worker: AutomationRunWorker)
        assert length(jobs) == 1
        assert hd(jobs).args["automation_id"] == a2.id
      end)
    end
  end
end
