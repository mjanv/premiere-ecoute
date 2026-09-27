defmodule PremiereEcoute.Sessions.Scores.PostSessionVote do
  @moduledoc """
  Post-session voting for viewers who missed the live session.

  Allows viewers with zero votes in a stopped session to submit track votes
  directly (bypassing the Broadway chat pipeline) and triggers a report refresh.
  """

  import Ecto.Query

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Playlist
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

  Only accepts a stopped session and at least one vote. The whole batch is
  rejected with `{:error, :invalid_votes}` if any value is not one of the session
  vote options or any track does not belong to the session album or playlist.
  Existing votes for the same (viewer, session, track) triple are silently
  ignored via on_conflict.
  """
  @spec submit(ListeningSession.t(), User.t(), %{integer() => String.t()}) ::
          {:ok, Report.t()} | {:error, term()}
  def submit(%ListeningSession{status: :stopped} = session, %User{twitch: %{user_id: viewer_id}}, votes) do
    if valid_votes?(session, votes) do
      insert_votes(session, viewer_id, votes)
    else
      {:error, :invalid_votes}
    end
  end

  def submit(_session, _viewer_id, _votes), do: {:error, :invalid}

  defp valid_votes?(%ListeningSession{vote_options: vote_options} = session, votes) do
    track_ids = session_track_ids(session)

    Enum.all?(votes, fn {track_id, value} -> value in vote_options and MapSet.member?(track_ids, track_id) end)
  end

  defp session_track_ids(%ListeningSession{source: :album, album_id: album_id}) do
    from(t in Album.Track, where: t.album_id == ^album_id, select: t.id) |> Repo.all() |> MapSet.new()
  end

  defp session_track_ids(%ListeningSession{source: :playlist, playlist_id: playlist_id}) do
    from(t in Playlist.Track, where: t.playlist_id == ^playlist_id, select: t.id) |> Repo.all() |> MapSet.new()
  end

  defp session_track_ids(_session), do: MapSet.new()

  defp insert_votes(%ListeningSession{id: session_id} = session, viewer_id, votes) do
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
end
