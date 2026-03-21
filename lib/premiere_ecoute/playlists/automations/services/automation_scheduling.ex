defmodule PremiereEcoute.Playlists.Automations.Services.AutomationScheduling do
  @moduledoc """
  Schedules and cancels Oban jobs for automation runs.

  Wraps `Oban.insert` so callers don't depend on the worker module directly.
  `cancel/1` cancels all non-executing planned jobs for the automation before
  edits or deletions.
  """

  import Ecto.Query

  alias Crontab.CronExpression
  alias Crontab.Scheduler, as: CrontabScheduler
  alias PremiereEcoute.Playlists.Automations.Automation
  alias PremiereEcoute.Playlists.Automations.Workers.AutomationRunWorker
  alias PremiereEcoute.Repo

  @doc "Inserts a job to run the automation immediately, regardless of schedule or enabled state."
  @spec run_now(Automation.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def run_now(%Automation{id: id}) do
    %{automation_id: id}
    |> AutomationRunWorker.new()
    |> Oban.insert()
  end

  @doc "Schedules the appropriate job for an automation based on its schedule field."
  @spec schedule(Automation.t()) :: :ok | {:ok, Oban.Job.t()} | {:error, term()}
  def schedule(%Automation{enabled: false}), do: :ok

  def schedule(%Automation{schedule: :manual}), do: :ok

  def schedule(%Automation{schedule: :once, scheduled_at: nil}), do: :ok

  def schedule(%Automation{id: id, schedule: :once, scheduled_at: at}) do
    %{automation_id: id}
    |> AutomationRunWorker.new(scheduled_at: at)
    |> Oban.insert()
  end

  def schedule(%Automation{id: id, schedule: :recurring, cron_expression: expr}) do
    %{automation_id: id}
    |> AutomationRunWorker.new(scheduled_at: next_run_at(expr))
    |> Oban.insert()
  end

  @doc "Cancels all pending/scheduled Oban jobs for the automation."
  @spec cancel(Automation.t()) :: :ok
  def cancel(%Automation{id: id}) do
    from(j in Oban.Job,
      where: j.worker == ^"PremiereEcoute.Playlists.Automations.Workers.AutomationRunWorker",
      where: fragment("?->>'automation_id' = ?", j.args, ^to_string(id)),
      where: j.state in ["scheduled", "available", "retryable"]
    )
    |> Repo.all(prefix: "oban")
    |> Enum.each(&Oban.cancel_job(&1.id))

    :ok
  end

  @doc "Computes the next run datetime for a cron expression."
  @spec next_run_at(String.t()) :: DateTime.t()
  def next_run_at(cron_expression) do
    cron_expression
    |> CronExpression.Parser.parse()
    |> then(fn {:ok, expr} -> expr end)
    |> CrontabScheduler.get_next_run_date!(NaiveDateTime.utc_now())
    |> DateTime.from_naive!("Etc/UTC")
  end
end
