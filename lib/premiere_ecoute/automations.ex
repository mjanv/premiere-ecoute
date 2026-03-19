defmodule PremiereEcoute.Automations do
  @moduledoc """
  Public context for playlist automations.

  All external callers use this module — internal schemas, services, and workers
  are not part of the public API.
  """

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Playlists.Automations.ActionRegistry
  alias PremiereEcoute.Playlists.Automations.Automation
  alias PremiereEcoute.Playlists.Automations.AutomationRun
  alias PremiereEcoute.Playlists.Automations.Services.AutomationCreation
  alias PremiereEcoute.Playlists.Automations.Services.AutomationScheduling
  alias PremiereEcoute.Repo

  @doc "Lists all automations for a user."
  defdelegate list_automations(user), to: Automation, as: :list_for_user

  @doc "Gets a single automation by id."
  @spec get_automation(integer()) :: Automation.t() | nil
  def get_automation(id), do: Repo.get(Automation, id)

  @doc "Creates an automation and schedules its first run."
  defdelegate create_automation(user, attrs), to: AutomationCreation, as: :create

  @doc "Updates an automation, cancelling and rescheduling as needed."
  defdelegate update_automation(automation, attrs), to: AutomationCreation, as: :update

  @doc "Enables an automation."
  defdelegate enable_automation(automation), to: AutomationCreation, as: :enable

  @doc "Disables an automation."
  defdelegate disable_automation(automation), to: AutomationCreation, as: :disable

  @doc "Deletes an automation and cancels pending jobs."
  defdelegate delete_automation(automation), to: AutomationCreation, as: :delete

  @doc "Triggers an immediate run for a manual automation."
  @spec run_now(Automation.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def run_now(%Automation{} = automation), do: AutomationScheduling.schedule(automation)

  @doc "Lists run history for an automation."
  defdelegate list_runs(automation), to: AutomationRun, as: :list_for_automation

  @doc "Returns the next scheduled run datetime for a cron expression."
  defdelegate next_run_at(cron_expression), to: AutomationScheduling

  @doc "Returns all registered action types and their modules."
  @spec action_registry() :: %{String.t() => module()}
  def action_registry, do: ActionRegistry.all()

  @doc "Populates virtual fields next_run_at and last_run_at for a list of automations."
  @spec with_virtual_fields(User.t(), [Automation.t()]) :: [Automation.t()]
  def with_virtual_fields(%User{}, automations) do
    # AIDEV-NOTE: next_run_at from oban_jobs, last_run_at from automation_runs;
    # loaded in bulk to avoid N+1 queries
    automation_ids = Enum.map(automations, & &1.id)

    last_runs = last_run_at_map(automation_ids)
    next_runs = next_run_at_map(automation_ids)

    Enum.map(automations, fn a ->
      %{a | last_run_at: Map.get(last_runs, a.id), next_run_at: Map.get(next_runs, a.id)}
    end)
  end

  defp last_run_at_map([]), do: %{}

  defp last_run_at_map(ids) do
    import Ecto.Query

    AutomationRun
    |> where([r], r.automation_id in ^ids)
    |> group_by([r], r.automation_id)
    |> select([r], {r.automation_id, max(r.inserted_at)})
    |> Repo.all()
    |> Map.new()
  end

  defp next_run_at_map([]), do: %{}

  defp next_run_at_map(ids) do
    import Ecto.Query

    worker = "PremiereEcoute.Playlists.Automations.Workers.AutomationRunWorker"

    Oban.Job
    |> where([j], j.worker == ^worker and j.state in ["scheduled", "available"])
    |> where([j], fragment("(?->>'automation_id')::bigint", j.args) in ^ids)
    |> group_by([j], fragment("(?->>'automation_id')::bigint", j.args))
    |> select([j], {fragment("(?->>'automation_id')::bigint", j.args), min(j.scheduled_at)})
    |> Repo.all(prefix: "oban")
    |> Map.new()
  end
end
