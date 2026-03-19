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

  @doc "Schedules an immediate run for a manual automation."
  @spec schedule(Automation.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def schedule(%Automation{id: id, schedule_type: :manual}) do
    %{automation_id: id}
    |> AutomationRunWorker.new()
    |> Oban.insert()
  end

  @doc "Schedules a one-time run at the given datetime."
  @spec schedule(Automation.t(), DateTime.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def schedule(%Automation{id: id, schedule_type: :once}, at) do
    %{automation_id: id}
    |> AutomationRunWorker.new(scheduled_at: at)
    |> Oban.insert()
  end

  @doc "Schedules the next recurring run based on the cron expression."
  @spec schedule_next(Automation.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def schedule_next(%Automation{id: id, schedule_type: :recurring, cron_expression: expr}) do
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
    {:ok, expr} = CronExpression.Parser.parse(cron_expression)
    naive = CrontabScheduler.get_next_run_date!(expr, NaiveDateTime.utc_now())
    DateTime.from_naive!(naive, "Etc/UTC")
  end
end
