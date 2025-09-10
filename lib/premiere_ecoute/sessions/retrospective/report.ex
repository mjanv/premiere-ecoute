defmodule PremiereEcoute.Sessions.Retrospective.Report do
  @moduledoc false

  use PremiereEcouteCore.Aggregate,
    root: [:votes, :polls]

  require Logger

  alias Ecto.Adapters.SQL

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Poll
  alias PremiereEcoute.Sessions.Scores.Vote

  @type session_summary :: %{
          unique_votes: integer(),
          unique_voters: integer(),
          viewer_score: float() | String.t(),
          streamer_score: float() | String.t(),
          tracks_rated: integer()
        }

  @type track_summary :: %{
          track_id: integer(),
          unique_votes: integer(),
          unique_voters: integer(),
          viewer_score: float() | String.t(),
          streamer_score: float() | String.t(),
          poll_count: integer()
        }

  @type t :: %__MODULE__{
          id: integer(),
          session_summary: session_summary(),
          track_summaries: [track_summary()],
          session_id: integer(),
          session: ListeningSession.t(),
          votes: [Vote.t()],
          polls: [Poll.t()],
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "reports" do
    field :session_summary, :map
    field :track_summaries, {:array, :map}

    belongs_to :session, ListeningSession

    has_many :votes, Vote, foreign_key: :session_id, references: :session_id
    has_many :polls, Poll, foreign_key: :session_id, references: :session_id

    timestamps()
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [
      :session_summary,
      :track_summaries,
      :session_id
    ])
    |> validate_required([:session_id])
    |> foreign_key_constraint(:session_id)
  end

  @doc """
  Generates a comprehensive report for a listening session.

  If a report already exists for the session, it will be updated with fresh data.
  If no report exists, a new one will be created.

  This is the main business logic function that combines all vote sources:
  1. Individual votes (viewers + streamer)
  2. Twitch polls
  3. Calculates unique voter counts and aggregated scores

  The scoring logic adapts based on the session's vote_options:
  - Integer values: scores computed as averages
  - String values: scores computed as most frequent ("even" if tied)

  ## Examples

      iex> generate(%ListeningSession{id: 123})
      {:ok, %Report{}}
  """
  @spec generate(ListeningSession.t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def generate(%ListeningSession{id: session_id} = session) do
    votes = Vote.all(where: [session_id: session_id]) 
    polls = Poll.all(where: [session_id: session_id])

    session_stats = calculate_session_stats(session_id)

    session_summary =
      session
      |> calculate_session_summary(votes, polls)
      |> Map.merge(session_stats)

    attrs = %{
      session_id: session_id,
      session_summary: session_summary,
      track_summaries: calculate_track_summaries(session, votes, polls)
    }

    case get_by(session_id: session_id) do
      nil ->
        %__MODULE__{}
        |> changeset(attrs)
        |> Repo.insert()

      report ->
        report
        |> changeset(attrs)
        |> Repo.update()
    end
    |> case do
      {:ok, report} ->
        {:ok, preload(report)}

      {:error, reason} ->
        Logger.error("Cannot generate report due to: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp vote_options_are_integers?(vote_options) do
    Enum.all?(vote_options, fn option ->
      case Integer.parse(option) do
        {_int, ""} -> true
        _ -> false
      end
    end)
  end

  defp calculate_average_score(votes) when is_list(votes) do
    if Enum.empty?(votes) do
      0.0
    else
      numeric_votes =
        votes
        |> Enum.map(fn vote ->
          case Integer.parse(vote) do
            {int, ""} -> int
            _ -> 0
          end
        end)

      (Enum.sum(numeric_votes) / length(numeric_votes)) |> Float.round(1)
    end
  end

  defp calculate_most_frequent(votes) when is_list(votes) do
    if Enum.empty?(votes) do
      "even"
    else
      votes
      |> Enum.frequencies()
      |> case do
        frequencies when map_size(frequencies) == 0 ->
          "even"

        frequencies ->
          max_count = frequencies |> Map.values() |> Enum.max()

          most_frequent =
            frequencies
            |> Enum.filter(fn {_value, count} -> count == max_count end)
            |> Enum.map(fn {value, _count} -> value end)

          case length(most_frequent) do
            1 -> hd(most_frequent)
            _ -> "even"
          end
      end
    end
  end

  defp calculate_session_stats(session_id) do
    query = """
    SELECT
      COALESCE(individual_votes, 0) as individual_votes,
      COALESCE(poll_votes, 0) as poll_votes,
      COALESCE(unique_individual_voters, 0) + COALESCE(poll_votes, 0) as unique_voters
    FROM (
      SELECT COUNT(*) as individual_votes
      FROM votes
      WHERE session_id = $1
    ) votes_count
    CROSS JOIN (
      SELECT COALESCE(SUM(total_votes), 0) as poll_votes
      FROM polls
      WHERE session_id = $1
    ) polls_count
    CROSS JOIN (
      SELECT COUNT(DISTINCT viewer_id) as unique_individual_voters
      FROM votes
      WHERE session_id = $1 AND is_streamer = false
    ) unique_count
    """

    result = SQL.query!(Repo, query, [session_id])
    [[individual_votes, poll_votes, unique_voters]] = result.rows

    %{
      unique_votes: individual_votes + poll_votes,
      unique_voters: unique_voters
    }
  end

  defp calculate_session_summary(%ListeningSession{vote_options: vote_options}, votes, polls) do
    # Get all track IDs that have votes or polls
    track_ids_with_votes = votes |> Enum.map(& &1.track_id) |> Enum.uniq()
    track_ids_with_polls = polls |> Enum.map(& &1.track_id) |> Enum.uniq()
    all_track_ids = (track_ids_with_votes ++ track_ids_with_polls) |> Enum.uniq()

    tracks_rated = length(all_track_ids)

    {viewer_score, streamer_score} =
      if vote_options_are_integers?(vote_options) do
        # For integer options: calculate track averages, then session average
        viewer_scores_per_track =
          all_track_ids
          |> Enum.map(fn track_id ->
            calculate_track_viewer_score(track_id, vote_options, votes, polls)
          end)
          |> Enum.reject(&is_nil/1)

        streamer_scores_per_track =
          all_track_ids
          |> Enum.map(fn track_id ->
            calculate_track_streamer_score(track_id, vote_options, votes)
          end)
          |> Enum.reject(&is_nil/1)

        viewer_score =
          if Enum.empty?(viewer_scores_per_track) do
            0.0
          else
            Enum.sum(viewer_scores_per_track) / length(viewer_scores_per_track)
          end
          |> Float.round(1)

        streamer_score =
          if Enum.empty?(streamer_scores_per_track) do
            0.0
          else
            Enum.sum(streamer_scores_per_track) / length(streamer_scores_per_track)
          end
          |> Float.round(1)

        {viewer_score, streamer_score}
      else
        # For string options: get all individual votes across all tracks, then find most frequent
        all_viewer_votes =
          votes
          |> Enum.filter(fn vote -> vote.track_id in all_track_ids and not vote.is_streamer end)
          |> Enum.map(& &1.value)

        all_streamer_votes =
          votes
          |> Enum.filter(fn vote -> vote.track_id in all_track_ids and vote.is_streamer end)
          |> Enum.map(& &1.value)

        # Add poll votes for all tracks
        all_poll_votes =
          polls
          |> Enum.filter(fn poll -> poll.track_id in all_track_ids end)
          |> Enum.flat_map(fn poll ->
            case extract_poll_score(poll, vote_options) do
              nil -> []
              score -> [score]
            end
          end)

        viewer_score = calculate_most_frequent(all_viewer_votes ++ all_poll_votes)
        streamer_score = calculate_most_frequent(all_streamer_votes)

        {viewer_score, streamer_score}
      end

    %{
      viewer_score: viewer_score,
      streamer_score: streamer_score,
      tracks_rated: tracks_rated
    }
  end

  defp calculate_track_viewer_score(track_id, vote_options, votes, polls) do
    individual_votes =
      votes
      |> Enum.filter(fn vote -> vote.track_id == track_id and not vote.is_streamer end)
      |> Enum.map(& &1.value)

    poll_scores =
      polls
      |> Enum.filter(fn poll -> poll.track_id == track_id end)
      |> Enum.map(fn poll -> extract_poll_score(poll, vote_options) end)
      |> Enum.reject(&is_nil/1)

    if vote_options_are_integers?(vote_options) do
      # For integers: average the individual average with poll averages
      individual_avg =
        if Enum.empty?(individual_votes) do
          nil
        else
          calculate_average_score(individual_votes)
        end

      # Combine individual average with poll averages
      all_averages =
        ([individual_avg] ++ poll_scores)
        |> Enum.reject(&is_nil/1)

      if Enum.empty?(all_averages) do
        nil
      else
        Enum.sum(all_averages) / length(all_averages)
      end
    else
      # For strings: compute most frequent for individual votes and polls separately, then decide
      individual_result =
        if Enum.empty?(individual_votes) do
          nil
        else
          calculate_most_frequent(individual_votes)
        end

      poll_results =
        polls
        |> Enum.filter(fn poll -> poll.track_id == track_id end)
        |> Enum.map(fn poll -> extract_poll_score(poll, vote_options) end)
        |> Enum.reject(&is_nil/1)

      # Combine individual result with poll results, with individual votes taking priority in ties
      all_results =
        ([individual_result] ++ poll_results)
        |> Enum.reject(&is_nil/1)

      if Enum.empty?(all_results) do
        nil
      else
        result = calculate_most_frequent(all_results)
        # If tie and we have individual votes, prefer individual result
        if result == "even" and not is_nil(individual_result) do
          individual_result
        else
          result
        end
      end
    end
  end

  defp calculate_track_streamer_score(track_id, vote_options, votes) do
    streamer_votes =
      votes
      |> Enum.filter(fn vote -> vote.track_id == track_id and vote.is_streamer end)
      |> Enum.map(& &1.value)

    if Enum.empty?(streamer_votes) do
      nil
    else
      if vote_options_are_integers?(vote_options) do
        calculate_average_score(streamer_votes)
      else
        calculate_most_frequent(streamer_votes)
      end
    end
  end

  defp extract_poll_score(poll, vote_options) do
    if vote_options_are_integers?(vote_options) do
      # For integer options, calculate weighted average
      total_votes = poll.total_votes || 0

      if total_votes == 0 do
        nil
      else
        weighted_sum =
          vote_options
          |> Enum.reduce(0, fn option, acc ->
            case Integer.parse(option) do
              {value, ""} ->
                vote_count = Map.get(poll.votes || %{}, option, 0)
                acc + value * vote_count

              _ ->
                acc
            end
          end)

        weighted_sum / total_votes
      end
    else
      # For string options, find most frequent
      if is_nil(poll.votes) or poll.total_votes == 0 do
        nil
      else
        poll.votes
        |> Enum.max_by(fn {_option, count} -> count end, fn -> {nil, 0} end)
        |> case do
          {option, count} ->
            # Check if there's a tie
            max_count = count

            tied_options =
              poll.votes
              |> Enum.filter(fn {_option, count} -> count == max_count end)
              |> Enum.map(fn {option, _count} -> option end)

            case length(tied_options) do
              1 -> option
              _ -> "even"
            end

          _ ->
            nil
        end
      end
    end
  end

  defp calculate_track_summaries(%ListeningSession{vote_options: vote_options}, votes, polls) do
    # Get all track IDs that have votes or polls
    track_ids_with_votes = votes |> Enum.map(& &1.track_id) |> Enum.uniq()
    track_ids_with_polls = polls |> Enum.map(& &1.track_id) |> Enum.uniq()
    all_track_ids = (track_ids_with_votes ++ track_ids_with_polls) |> Enum.uniq()

    all_track_ids
    |> Enum.map(fn track_id ->
      # Calculate scores for this track
      viewer_score = calculate_track_viewer_score(track_id, vote_options, votes, polls)
      streamer_score = calculate_track_streamer_score(track_id, vote_options, votes)

      # Count stats for this track
      track_votes = Enum.filter(votes, fn vote -> vote.track_id == track_id end)
      track_polls = Enum.filter(polls, fn poll -> poll.track_id == track_id end)

      unique_votes = length(track_votes)
      poll_count = track_polls |> Enum.map(&(&1.total_votes || 0)) |> Enum.sum()

      unique_individual_voters =
        track_votes
        |> Enum.filter(fn vote -> not vote.is_streamer end)
        |> Enum.map(& &1.viewer_id)
        |> Enum.uniq()
        |> length()

      unique_voters = unique_individual_voters + poll_count

      %{
        track_id: track_id,
        viewer_score: viewer_score || if(vote_options_are_integers?(vote_options), do: 0.0, else: "even"),
        streamer_score: streamer_score || if(vote_options_are_integers?(vote_options), do: 0.0, else: "even"),
        unique_votes: unique_votes,
        poll_count: poll_count,
        unique_voters: unique_voters
      }
    end)
    |> Enum.sort_by(& &1.track_id)
  end
end
