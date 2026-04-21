defmodule PremiereEcoute.Collections do
  @moduledoc """
  Collections context.

  Manages collection session lifecycle, tracklist curation, and duel reminder scheduling.
  """

  use PremiereEcouteCore.Context

  alias PremiereEcoute.Collections.CollectionSession
  alias PremiereEcoute.Collections.CollectionSessionWorker
  alias PremiereEcoute.Collections.Tracklist

  # Collection sessions

  defdelegate get_session(id), to: CollectionSession, as: :get
  defdelegate all_sessions_for_user(user), to: CollectionSession, as: :all_for_user
  defdelegate delete_session(session), to: CollectionSession, as: :delete

  # Tracklist

  defdelegate shuffle_tracklist(session, broadcaster_id, tracks), to: Tracklist, as: :shuffle
  defdelegate restore_tracklist(session, broadcaster_id, tracks, original), to: Tracklist, as: :restore
  defdelegate reorder_tracklist(session, index, delta, broadcaster_id, tracks), to: Tracklist, as: :reorder
  defdelegate move_track_to_top(session, index, broadcaster_id, tracks), to: Tracklist, as: :move_to_top

  # Duel reminders

  @doc "Returns the scheduled_at of the next pending duel reminder for the session, or nil."
  @spec next_duel_reminder_at(integer()) :: DateTime.t() | nil
  defdelegate next_duel_reminder_at(session_id), to: CollectionSessionWorker

  @doc "Schedules a duel reminder job in the given number of minutes."
  @spec schedule_duel_reminder(integer(), integer()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def schedule_duel_reminder(session_id, minutes) do
    CollectionSessionWorker.in_minutes(
      %{"action" => "duel_reminder", "session_id" => session_id},
      minutes
    )
  end
end
