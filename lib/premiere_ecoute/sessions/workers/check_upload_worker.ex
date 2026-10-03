defmodule PremiereEcoute.Sessions.Workers.CheckUploadWorker do
  @moduledoc """
  Oban worker that looks for the uploaded replay of a listening session on YouTube.

  One job per `(session_id, replay_id)`. Each run checks the replay, stores the video when it finds it, and
  otherwise counts a failed iteration and inserts the job of the next check.
  """

  use PremiereEcouteCore.Worker,
    queue: :uploads,
    max_attempts: 3,
    unique: [period: :infinity, keys: [:session_id, :replay_id], states: [:available, :scheduled, :retryable]]

  import Ecto.Query, only: [from: 2]

  alias PremiereEcoute.Accounts.User.Profile
  alias PremiereEcoute.Accounts.User.Profile.VideoSettings.Replay
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Services.ReplayVideo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"session_id" => session_id, "replay_id" => replay_id}}) do
    now = DateTime.utc_now(:second)

    with %ListeningSession{} = session <- session_id |> ListeningSession.get() |> ListeningSession.preload(),
         %Replay{} = replay <- Enum.find(Profile.get(session.user, [:video_settings, :replays], []), &(&1.id == replay_id)),
         %{"status" => "pending", "next_check_at" => next_check_at} <- get_in(session.options, ["uploads", replay_id]),
         false <- DateTime.after?(parse(next_check_at), now) do
      result = ReplayVideo.find_replay_video(session, replay)

      {:ok, outcome} =
        Repo.transaction(fn ->
          locked = Repo.one!(from(s in ListeningSession, where: s.id == ^session_id, lock: "FOR UPDATE"))

          case get_in(locked.options, ["uploads", replay_id]) do
            %{"status" => "pending"} = state ->
              state = state |> next_state(result, now) |> insert_next_check(session_id, replay_id)
              {:ok, stored} = ReplayVideo.store_replay_video(locked, replay, result)

              stored
              |> ListeningSession.changeset(%{options: put_in(locked.options, ["uploads", replay_id], state)})
              |> Repo.update!()

              :ok

            _ ->
              {:cancel, :not_pending}
          end
        end)

      outcome
    else
      nil -> {:cancel, :gone}
      true -> :ok
      %{} -> {:cancel, :not_pending}
    end
  end

  defp parse(iso8601), do: iso8601 |> DateTime.from_iso8601() |> elem(1)

  defp next_state(state, {:ok, _video}, now) do
    %{state | "status" => "found", "last_checked_at" => DateTime.to_iso8601(now), "next_check_at" => nil, "last_failure" => nil}
  end

  defp next_state(state, {:error, reason}, now) do
    iterations = state["iterations"] + 1
    exhausted? = iterations >= state["max_iterations"]
    next_check_at = DateTime.add(now, state["interval_hours"], :hour)

    %{
      state
      | "status" => if(exhausted?, do: "exhausted", else: "pending"),
        "iterations" => iterations,
        "last_checked_at" => DateTime.to_iso8601(now),
        "next_check_at" => if(exhausted?, do: nil, else: DateTime.to_iso8601(next_check_at)),
        "last_failure" => if(reason == :not_found, do: "not_found", else: "api_error")
    }
  end

  defp insert_next_check(%{"status" => "pending", "next_check_at" => at} = state, session_id, replay_id) do
    {:ok, job} = start(%{session_id: session_id, replay_id: replay_id}, scheduled_at: parse(at))
    %{state | "job_id" => job.id}
  end

  defp insert_next_check(state, _session_id, _replay_id), do: %{state | "job_id" => nil}
end
