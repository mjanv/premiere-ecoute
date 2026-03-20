defmodule PremiereEcoute.Notifications.Workers.NotificationPruner do
  @moduledoc """
  Oban cron worker that prunes stale notifications daily.

  Deletes notifications that have been read and are older than @retention_days.
  Unread notifications are never deleted — they remain visible until the user reads them.
  """

  use PremiereEcouteCore.Worker, queue: :notifications, max_attempts: 1

  require Logger

  alias PremiereEcoute.Notifications.Notification

  @retention_days 30

  @impl true
  def perform(%Oban.Job{}) do
    cutoff = DateTime.add(DateTime.utc_now(), -@retention_days, :day)

    case Notification.delete_read_before(cutoff) do
      0 -> :ok
      n -> Logger.info("Pruned #{n} stale notifications")
    end

    :ok
  end
end
