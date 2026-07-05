defmodule PremiereEcoute.Sessions.Scores.PostSessionVote do
  @moduledoc """
  Post-session voting for viewers who missed the live session.

  Allows viewers with zero votes in a stopped session to submit track votes
  directly (bypassing the Broadway chat pipeline) and triggers a report refresh.
  """

  import Ecto.Query

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Scores.Vote

  @doc """
  Returns true when the viewer has cast more than one vote in a stopped session.
  """
  @spec has_voted?(ListeningSession.t(), User.t()) :: boolean()
  def has_voted?(%ListeningSession{id: session_id, status: :stopped}, %User{twitch: %{user_id: user_id}}) do
    Repo.exists?(
      from(v in Vote,
        where: v.session_id == ^session_id and v.viewer_id == ^user_id,
        select: count(v.id)
      )
    )
  end

  def has_voted?(_, _), do: false

  @doc """
  Inserts post-session votes and regenerates the session report.

  Only accepts a stopped session and at least one vote. Existing votes for the
  same (viewer, session, track) triple are silently ignored via on_conflict.
  """
  @spec submit(ListeningSession.t(), User.t(), %{integer() => String.t()}) ::
          {:ok, Report.t()} | {:error, term()}
  def submit(%ListeningSession{id: session_id, status: :stopped} = session, %User{twitch: %{user_id: viewer_id}}, votes) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    votes
    |> Enum.map(fn {track_id, value} ->
      %{
        viewer_id: viewer_id,
        session_id: session_id,
        track_id: track_id,
        value: value,
        is_streamer: false,
        inserted_at: now,
        updated_at: now
      }
    end)
    |> Vote.create_all(on_conflict: :nothing)
    |> then(fn
      {:ok, _} -> Report.generate(session)
      error -> error
    end)
  end

  def submit(_session, _viewer_id, _votes), do: {:error, :invalid}
end
