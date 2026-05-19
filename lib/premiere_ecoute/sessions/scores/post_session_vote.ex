defmodule PremiereEcoute.Sessions.Scores.PostSessionVote do
  @moduledoc """
  Post-session voting for viewers who missed the live session.

  Allows viewers with zero votes in a stopped session to submit track votes
  directly (bypassing the Broadway chat pipeline) and triggers a report refresh.
  """

  import Ecto.Query

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Scores.Vote

  @doc """
  Returns true when the viewer has cast zero votes in this session.

  Eligibility is scoped to the session — viewers who voted on some tracks during
  the live stream are not eligible.
  """
  @spec eligible?(integer(), String.t()) :: boolean()
  def eligible?(session_id, viewer_id) do
    from(v in Vote,
      where: v.session_id == ^session_id and v.viewer_id == ^viewer_id,
      select: count(v.id)
    )
    |> Repo.one()
    |> Kernel.==(0)
  end

  @doc """
  Inserts post-session votes and regenerates the session report.

  Only accepts a stopped session and at least one vote. Existing votes for the
  same (viewer, session, track) triple are silently ignored via on_conflict.
  """
  @spec submit(ListeningSession.t(), String.t(), %{integer() => String.t()}) ::
          {:ok, Report.t()} | {:error, term()}
  def submit(
        %ListeningSession{id: session_id, status: :stopped} = session,
        viewer_id,
        votes_by_track_id
      )
      when is_binary(viewer_id) and map_size(votes_by_track_id) > 0 do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    vote_entries =
      Enum.map(votes_by_track_id, fn {track_id, value} ->
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

    Vote.create_all(vote_entries, on_conflict: :nothing)
    Report.generate(session)
  end

  def submit(_session, _viewer_id, _votes), do: {:error, :invalid}
end
