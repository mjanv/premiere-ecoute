defmodule PremiereEcoute.Playlists.Automations.Workers.AutomationRunWorker do
  @moduledoc """
  Oban worker that executes a single automation run.

  Execution order per PLAN.md:
  1. Load automation
  2. Schedule next run FIRST (recurring) or disable (once)
  3. Insert automation_run record
  4. Build user scope
  5. Execute steps via AutomationExecution
  6. Update run with final status

  The job always returns `:ok` — domain failures are recorded in automation_runs,
  not surfaced as job errors, to prevent Oban from retrying destructive steps.
  """

  use Oban.Worker, queue: :automations, max_attempts: 1

  alias PremiereEcoute.Playlists.Automations.Automation
  alias PremiereEcoute.Playlists.Automations.Services.AutomationExecution
  alias PremiereEcoute.Playlists.Automations.Services.AutomationScheduling
  alias PremiereEcoute.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{id: job_id, args: %{"automation_id" => automation_id}}) do
    case Repo.get(Automation, automation_id) do
      nil ->
        :ok

      %Automation{schedule: :recurring} = automation ->
        AutomationScheduling.schedule(automation)
        AutomationExecution.run(automation, job_id)
        :ok

      %Automation{schedule: :once} = automation ->
        Automation.update(automation, %{enabled: false})
        AutomationExecution.run(automation, job_id)
        :ok

      %Automation{schedule: :manual} = automation ->
        AutomationExecution.run(automation, job_id)
        :ok
    end
  end
end
