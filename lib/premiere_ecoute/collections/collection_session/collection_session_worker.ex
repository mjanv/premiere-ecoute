defmodule PremiereEcoute.Collections.CollectionSessionWorker do
  @moduledoc """
  Oban worker for collection session background tasks.

  Handles scheduled vote window close after vote_duration expires.
  """

  use PremiereEcouteCore.Worker,
    queue: :sessions,
    max_attempts: 1,
    unique: [period: 5, keys: [:action, :session_id]]

  use Gettext, backend: PremiereEcoute.Gettext

  require Logger

  alias PremiereEcoute.Collections.CollectionSession
  alias PremiereEcoute.Repo

  import Ecto.Query

  @doc "Returns the scheduled_at of the next pending duel_reminder job for the given session, or nil."
  @spec next_duel_reminder_at(integer()) :: DateTime.t() | nil
  def next_duel_reminder_at(session_id) do
    duel_reminder_query(session_id)
    |> select([j], j.scheduled_at)
    |> limit(1)
    |> Repo.one(prefix: "oban")
  end

  @doc "Cancels all pending duel_reminder jobs for the given session."
  @spec cancel_duel_reminders(integer()) :: :ok
  def cancel_duel_reminders(session_id) do
    duel_reminder_query(session_id)
    |> Oban.cancel_all_jobs()
  end

  defp duel_reminder_query(session_id) do
    Oban.Job
    |> where([j], j.worker == ^inspect(__MODULE__))
    |> where([j], fragment("(?->>'action')", j.args) == "duel_reminder")
    |> where([j], fragment("(?->>'session_id')::bigint", j.args) == ^session_id)
    |> order_by([j], asc: j.scheduled_at)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "duel_reminder", "session_id" => session_id}}) do
    case CollectionSession.get(session_id) do
      %CollectionSession{status: :active} ->
        PremiereEcoute.PubSub.broadcast("collection:#{session_id}", {:duel_reminder, nil})

      _ ->
        :ok
    end

    :ok
  end
end
