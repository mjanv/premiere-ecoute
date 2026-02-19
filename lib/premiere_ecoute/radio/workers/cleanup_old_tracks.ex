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
    Accounts.streamers()
    |> Enum.filter(fn user -> Accounts.profile(user, [:radio_settings, :enabled], false) end)
    |> Enum.each(fn user ->
      retention_days = Accounts.profile(user, [:radio_settings, :retention_days], 7)
      cutoff_datetime = DateTime.add(DateTime.utc_now(), -retention_days, :day)

      {deleted_count, _} = Radio.delete_tracks_before(user.id, cutoff_datetime)

      if deleted_count > 0 do
        Logger.info("Deleted #{deleted_count} old radio tracks for user #{user.id}")
      end
    end)

    :ok
  end
end
