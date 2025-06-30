defmodule PremiereEcoute.Sessions do
  @moduledoc """
  The Sessions context for managing listening sessions, albums, and voting.
  """

  import Ecto.Query, warn: false

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Vote

  @doc """
  Gets all votes for a listening session.
  """
  def get_session_votes(session_id) do
    votes =
      from(v in Vote,
        where: v.session_id == ^session_id,
        preload: [:track]
      )
      |> Repo.all()

    {:ok, votes}
  end

  @doc """
  Gets aggregated scores for a listening session.
  This returns vote-based scores since the Report schema doesn't track individual track scores.
  """
  def get_session_scores(session_id) do
    # Calculate average scores from votes for each track
    scores =
      from(v in Vote,
        where: v.session_id == ^session_id,
        group_by: v.track_id,
        select: %{
          track_id: v.track_id,
          average_score: avg(v.value),
          vote_count: count(v.id)
        }
      )
      |> Repo.all()

    {:ok, scores}
  end

  @doc """
  Gets the currently playing track for a session.
  This is a placeholder - in a real implementation this would
  track the current playback state.
  """
  def get_current_playing_track(_session_id) do
    {:ok, nil}
  end

  @doc """
  Lists all listening sessions.
  """
  def list_listening_sessions do
    Repo.all(ListeningSession)
    |> Repo.preload([:album, :user])
  end
end
