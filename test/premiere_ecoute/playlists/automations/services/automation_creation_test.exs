defmodule PremiereEcoute.Playlists.Automations.Services.AutomationCreationTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Playlists.Automations.Automation
  alias PremiereEcoute.Playlists.Automations.Services.AutomationCreation
  alias PremiereEcoute.Playlists.Automations.Workers.AutomationRunWorker

  defp insert_automation(user, attrs) do
    {:ok, a} = Automation.insert(user, attrs)
    a
  end

  describe "create/2" do
    test "persists the automation" do
      user = user_fixture()

      assert {:ok, automation} =
               AutomationCreation.create(user, %{name: "Test", schedule: :manual})

      assert automation.id
      assert automation.name == "Test"
    end

    test "returns error for invalid attrs" do
      user = user_fixture()

      assert {:error, changeset} = AutomationCreation.create(user, %{schedule: :manual})
      assert Keyword.has_key?(changeset.errors, :name)
    end

    test "does not enqueue a job for manual automation" do
      user = user_fixture()

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _} = AutomationCreation.create(user, %{name: "Manual", schedule: :manual})
        refute_enqueued worker: AutomationRunWorker
      end)
    end

    test "enqueues a job for recurring automation" do
      user = user_fixture()

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, automation} =
          AutomationCreation.create(user, %{
            name: "Recurring",
            schedule: :recurring,
            cron_expression: "0 9 * * *"
          })

        assert_enqueued worker: AutomationRunWorker,
                        args: %{"automation_id" => automation.id}
      end)
    end

    test "enqueues a job for :once automation when scheduled_at provided" do
      user = user_fixture()
      at = DateTime.add(DateTime.utc_now(), 3600, :second)

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, automation} =
          AutomationCreation.create(user, %{
            name: "Once",
            schedule: :once,
            scheduled_at: at
          })

        assert_enqueued worker: AutomationRunWorker,
                        args: %{"automation_id" => automation.id}
      end)
    end
  end

  describe "update/2" do
    test "updates the automation" do
      user = user_fixture()
      automation = insert_automation(user, %{name: "Old", schedule: :manual})

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, updated} = AutomationCreation.update(automation, %{name: "New"})
        assert updated.name == "New"
      end)
    end

    test "cancels old job and enqueues new one when updating recurring" do
      user = user_fixture()

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, automation} =
          AutomationCreation.create(user, %{
            name: "Rec",
            schedule: :recurring,
            cron_expression: "0 9 * * *"
          })

        # Update cron expression — old job cancelled, new one enqueued
        {:ok, _} = AutomationCreation.update(automation, %{cron_expression: "0 10 * * *"})

        jobs = all_enqueued(worker: AutomationRunWorker)
        assert length(jobs) == 1
      end)
    end

    test "does not enqueue when updating a disabled automation" do
      user = user_fixture()

      Oban.Testing.with_testing_mode(:manual, fn ->
        automation =
          insert_automation(user, %{name: "Rec", schedule: :recurring, cron_expression: "0 9 * * *", enabled: false})

        {:ok, _} = AutomationCreation.update(automation, %{name: "Renamed"})
        refute_enqueued worker: AutomationRunWorker
      end)
    end
  end

  describe "enable/1" do
    test "sets enabled to true" do
      user = user_fixture()
      automation = insert_automation(user, %{name: "A", schedule: :manual, enabled: false})

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, updated} = AutomationCreation.enable(automation)
        assert updated.enabled == true
      end)
    end

    test "enqueues a job for recurring automation on enable" do
      user = user_fixture()

      Oban.Testing.with_testing_mode(:manual, fn ->
        automation =
          insert_automation(user, %{
            name: "Rec",
            schedule: :recurring,
            cron_expression: "0 9 * * *",
            enabled: false
          })

        {:ok, _} = AutomationCreation.enable(automation)
        assert_enqueued worker: AutomationRunWorker, args: %{"automation_id" => automation.id}
      end)
    end
  end

  describe "disable/1" do
    test "sets enabled to false" do
      user = user_fixture()
      automation = insert_automation(user, %{name: "A", schedule: :manual})

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, updated} = AutomationCreation.disable(automation)
        assert updated.enabled == false
      end)
    end
  end

  describe "delete/1" do
    test "removes the automation from the database" do
      user = user_fixture()
      automation = insert_automation(user, %{name: "A", schedule: :manual})

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, _} = AutomationCreation.delete(automation)
        assert Repo.get(Automation, automation.id) == nil
      end)
    end
  end
end
