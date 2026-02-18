defmodule PremiereEcoute.Radio.Workers.CleanupOldTracks do
  @moduledoc """
  Oban worker for cleaning up old radio tracks.

  Runs daily to delete tracks older than each user's retention policy.
  Scheduled via Oban cron configuration.
  """

  use PremiereEcouteCore.Worker, queue: :cleanup, max_attempts: 1

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Radio

  @impl true
  def perform(%Oban.Job{}) do
    Logger.info("Starting cleanup of old radio tracks")

    Accounts.streamers()
    |> Enum.filter(fn user ->
      case user.profile.radio_settings do
        %{enabled: true} -> true
        _ -> false
      end
    end)
    |> Enum.each(fn user ->
      retention_days =
        case user.profile.radio_settings do
          %{retention_days: days} when is_integer(days) -> days
          _ -> 7
        end

      cutoff_datetime = DateTime.add(DateTime.utc_now(), -retention_days, :day)

      {deleted_count, _} = Radio.delete_tracks_before(user.id, cutoff_datetime)

      if deleted_count > 0 do
        Logger.info("Deleted #{deleted_count} old radio tracks for user #{user.id}")
      end
    end)

    Logger.info("Completed cleanup of old radio tracks")
    :ok
  end
end
