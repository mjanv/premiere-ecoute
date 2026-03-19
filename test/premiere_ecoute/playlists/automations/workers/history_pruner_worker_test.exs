defmodule PremiereEcoute.Playlists.Automations.Workers.HistoryPrunerWorkerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Playlists.Automations.Automation
  alias PremiereEcoute.Playlists.Automations.AutomationRun
  alias PremiereEcoute.Playlists.Automations.Workers.HistoryPrunerWorker

  defp insert_run(automation) do
    {:ok, run} =
      AutomationRun.insert(%{
        automation_id: automation.id,
        oban_job_id: 1,
        status: :completed,
        trigger: :manual
      })

    run
  end

  defp backdate(run, days_ago) do
    inserted_at = DateTime.add(DateTime.utc_now(), -days_ago, :day) |> DateTime.truncate(:second)

    Oban.Testing.with_testing_mode(:manual, fn ->
      Repo.update_all(
        from(r in AutomationRun, where: r.id == ^run.id),
        set: [inserted_at: inserted_at]
      )
    end)
  end

  describe "perform/1" do
    test "deletes runs older than 30 days" do
      user = user_fixture()
      {:ok, automation} = Automation.insert(user, %{name: "A", schedule_type: :manual})
      run = insert_run(automation)
      backdate(run, 31)

      assert :ok = perform_job(HistoryPrunerWorker, %{})
      assert Repo.get(AutomationRun, run.id) == nil
    end

    test "keeps runs within 30 days" do
      user = user_fixture()
      {:ok, automation} = Automation.insert(user, %{name: "A", schedule_type: :manual})
      run = insert_run(automation)
      backdate(run, 10)

      assert :ok = perform_job(HistoryPrunerWorker, %{})
      assert Repo.get(AutomationRun, run.id) != nil
    end
  end
end
