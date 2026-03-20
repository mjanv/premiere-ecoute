defmodule PremiereEcoute.Playlists.Automations.Workers.HistoryPrunerWorker do
  @moduledoc "Daily Oban cron job that deletes automation run history older than 30 days."

  use Oban.Worker, queue: :automations, max_attempts: 1

  alias PremiereEcoute.Playlists.Automations.AutomationRun

  @retention_days 30

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    AutomationRun.delete_before(DateTime.add(DateTime.utc_now(), -@retention_days, :day))
    :ok
  end
end
