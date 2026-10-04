defmodule PremiereEcoute.Sessions.Workers.CheckUploadNowWorker do
  @moduledoc """
  Oban worker that checks once, on demand, whether the replay of a listening session has been uploaded.

  It is not part of the scheduled checks of `CheckUploadWorker`: it has no iteration and leaves the schedule
  alone (see `ReplayVideo.check_upload_once/2`). Its result is broadcast on `uploads:<user_id>` as
  `{:replay_checked, session_id, replay_id, result}`, `result` being `:found`, `:not_found`, `:error` or
  `:settled` (the replay is not `pending` anymore), so the page can answer within seconds.
  """

  use PremiereEcouteCore.Worker,
    queue: :uploads,
    max_attempts: 1,
    unique: [period: :infinity, keys: [:session_id, :replay_id], states: [:available, :scheduled, :executing, :retryable]]

  require Logger

  alias PremiereEcoute.PubSub
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Services.ReplayVideo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"session_id" => session_id, "replay_id" => replay_id}}) do
    case ReplayVideo.check_upload_once(session_id, replay_id) do
      {:ok, outcome, replay, session} ->
        log(outcome, replay, session_id)
        broadcast(session, replay_id, summary(outcome))
        :ok

      {:error, reason} ->
        broadcast(ListeningSession.get(session_id), replay_id, :settled)
        {:cancel, reason}
    end
  end

  defp summary({:found, _video}), do: :found
  defp summary(:not_found), do: :not_found
  defp summary({:error, _reason}), do: :error

  defp log({:found, video}, replay, session_id),
    do: Logger.info("CheckUploadNowWorker: found #{video.url} for replay #{replay.name} of session #{session_id}")

  defp log(:not_found, replay, session_id),
    do: Logger.info("CheckUploadNowWorker: video not found yet for replay #{replay.name} of session #{session_id}")

  defp log({:error, reason}, replay, session_id),
    do: Logger.error("CheckUploadNowWorker: check failed for replay #{replay.name} of session #{session_id}: #{inspect(reason)}")

  defp broadcast(%ListeningSession{id: session_id, user_id: user_id}, replay_id, result),
    do: PubSub.broadcast("uploads:#{user_id}", {:replay_checked, session_id, replay_id, result})

  defp broadcast(nil, _replay_id, _result), do: :ok
end
