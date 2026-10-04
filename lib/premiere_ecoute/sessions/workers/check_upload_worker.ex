defmodule PremiereEcoute.Sessions.Workers.CheckUploadWorker do
  @moduledoc """
  Oban worker that looks for the uploaded replay of a listening session on YouTube.

  One job per `(session_id, replay_id)`. Each run checks the replay, stores the video when it finds it, and
  otherwise inserts the job of the next check, with one iteration less in its args: a job starts at the max and the replay is exhausted when it reaches 0.

  When a run changes the slot, it broadcasts `{:replay_updated, session_id, replay_id}` on `uploads:<user_id>`
  so the page can refresh the card.
  """

  use PremiereEcouteCore.Worker,
    queue: :uploads,
    max_attempts: 3,
    unique: [period: :infinity, keys: [:session_id, :replay_id], states: [:available, :scheduled, :retryable]]

  import Ecto.Query, only: [from: 2]

  require Logger

  alias PremiereEcoute.Accounts.User.Profile
  alias PremiereEcoute.Accounts.User.Profile.VideoSettings.Replay
  alias PremiereEcoute.PubSub
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Services.ReplayVideo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"session_id" => session_id, "replay_id" => replay_id} = args}) do
    now = DateTime.utc_now(:second)
    iteration = Map.get(args, "iteration", ReplayVideo.max_iterations())

    with %ListeningSession{} = session <- session_id |> ListeningSession.get() |> ListeningSession.preload(),
         %Replay{} = replay <- Enum.find(Profile.get(session.user, [:video_settings, :replays], []), &(&1.id == replay_id)),
         %{"status" => "pending"} <- ReplayVideo.slot(session.replays, replay_id) do
      result = ReplayVideo.find_replay_video(session, replay)

      {:ok, outcome} =
        Repo.transaction(fn ->
          locked = Repo.one!(from(s in ListeningSession, where: s.id == ^session_id, lock: "FOR UPDATE"))

          case ReplayVideo.slot(locked.replays, replay_id) do
            %{"status" => "pending"} = entry ->
              entry = settle(entry, result, replay, %{session_id: session_id, iteration: iteration, now: now})
              locked |> ListeningSession.changeset(%{replays: ReplayVideo.put_entry(entry, locked.replays)}) |> Repo.update!()

              :ok

            _ ->
              {:cancel, :not_pending}
          end
        end)

      if outcome == :ok, do: PubSub.broadcast("uploads:#{session.user_id}", {:replay_updated, session_id, replay_id})

      outcome
    else
      nil -> {:cancel, :gone}
      %{} -> {:cancel, :not_pending}
    end
  end

  defp settle(entry, {:ok, video}, replay, %{session_id: session_id, now: now}) do
    Logger.info("CheckUploadWorker: found #{video.url} for replay #{replay.name} of session #{session_id}")
    ReplayVideo.found_entry(entry, replay, video, "auto", now)
  end

  defp settle(entry, {:error, reason}, replay, %{session_id: session_id, iteration: iteration, now: now}) do
    entry = Map.put(entry, "last_checked_at", DateTime.to_iso8601(now))
    left = max(iteration - 1, 0)

    log_failure(reason, "replay #{replay.name} of session #{session_id}, #{left} checks left: #{inspect(reason)}")

    if left == 0 do
      Logger.warning("CheckUploadWorker: gave up on replay #{replay.name} of session #{session_id}, no video found")
      Map.merge(entry, %{"status" => "exhausted", "job_id" => nil})
    else
      args = %{session_id: session_id, replay_id: replay.id, iteration: left}
      {:ok, job} = start(args, scheduled_at: DateTime.add(now, ReplayVideo.interval_hours(), :hour))
      Map.put(entry, "job_id", job.id)
    end
  end

  defp log_failure(:not_found, message), do: Logger.info("CheckUploadWorker: video not found yet for #{message}")
  defp log_failure(_reason, message), do: Logger.error("CheckUploadWorker: check failed for #{message}")
end
