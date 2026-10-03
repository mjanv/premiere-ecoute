defmodule PremiereEcoute.Sessions.Workers.CheckUploadWorker do
  @moduledoc """
  Oban worker that checks whether the replay of a listening session has been uploaded to YouTube.

  One live job per `(session_id, replay_id)`.
  """

  use PremiereEcouteCore.Worker,
    queue: :uploads,
    max_attempts: 3,
    unique: [period: :infinity, keys: [:session_id, :replay_id], states: :incomplete]

  @impl Oban.Worker
  def perform(%Oban.Job{}), do: :ok
end
