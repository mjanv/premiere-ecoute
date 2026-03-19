defmodule PremiereEcoute.Playlists.Automations.Workers.AutomationRunWorkerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Playlists.Automations.Automation
  alias PremiereEcoute.Playlists.Automations.AutomationRun
  alias PremiereEcoute.Playlists.Automations.Workers.AutomationRunWorker

  defp build_manual_automation(user) do
    {:ok, a} = Automation.insert(user, %{name: "Test", schedule_type: :manual, steps: []})
    a
  end

  describe "perform/1" do
    test "runs the automation and creates a run record" do
      user = user_fixture()
      automation = build_manual_automation(user)

      assert :ok = perform_job(AutomationRunWorker, %{automation_id: automation.id})

      assert [run] = AutomationRun.list_for_automation(automation)
      assert run.status == :completed
    end

    test "returns :ok for missing automation (idempotent)" do
      assert :ok = perform_job(AutomationRunWorker, %{automation_id: 999_999})
    end

    test "disables a :once automation after running" do
      user = user_fixture()
      {:ok, automation} = Automation.insert(user, %{name: "Once", schedule_type: :once, steps: []})

      assert :ok = perform_job(AutomationRunWorker, %{automation_id: automation.id})

      updated = Repo.get(Automation, automation.id)
      assert updated.enabled == false
    end
  end
end
