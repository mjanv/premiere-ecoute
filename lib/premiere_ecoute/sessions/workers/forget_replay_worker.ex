defmodule PremiereEcoute.Sessions.Workers.ForgetReplayWorker do
  @moduledoc """
  Oban worker that cleans the sessions of a user after one of their replays was deleted from their settings.

  See `ReplayVideo.forget_replay/2`.
  """

  use PremiereEcouteCore.Worker, queue: :uploads, max_attempts: 3

  alias PremiereEcoute.Sessions.Services.ReplayVideo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "replay_id" => replay_id}}) do
    ReplayVideo.forget_replay(user_id, replay_id)
  end
end
