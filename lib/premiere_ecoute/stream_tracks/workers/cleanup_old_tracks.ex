defmodule PremiereEcoute.StreamTracks.Workers.CleanupOldTracks do
  @moduledoc """
  Oban worker for cleaning up old stream tracks.

  Runs daily to delete tracks older than each user's retention policy.
  Scheduled via Oban cron configuration.
  """

  use PremiereEcouteCore.Worker, queue: :cleanup, max_attempts: 1

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.StreamTracks

  @impl true
  def perform(%Oban.Job{}) do
    Logger.info("Starting cleanup of old stream tracks")

    # Get all streamers with stream tracking enabled
    users_with_tracking =
      Accounts.streamers()
      |> Enum.filter(fn user ->
        case user.profile.stream_track_settings do
          %{enabled: true} -> true
          _ -> false
        end
      end)

    # Clean up tracks for each user based on their retention policy
    Enum.each(users_with_tracking, fn user ->
      retention_days =
        case user.profile.stream_track_settings do
          %{retention_days: days} when is_integer(days) -> days
          _ -> 7
        end

      cutoff_datetime =
        DateTime.utc_now()
        |> DateTime.add(-retention_days, :day)

      {deleted_count, _} = StreamTracks.delete_tracks_before(user.id, cutoff_datetime)

      if deleted_count > 0 do
        Logger.info("Deleted #{deleted_count} old tracks for user #{user.id}")
      end
    end)

    Logger.info("Completed cleanup of old stream tracks")
    :ok
  end
end
