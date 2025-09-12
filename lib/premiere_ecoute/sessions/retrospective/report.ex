defmodule PremiereEcoute.Sessions.Retrospective.Report do
  @moduledoc false

  use PremiereEcouteCore.Aggregate,
    root: [:votes, :polls]

  require Logger

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
    mode =
      case session.vote_options do
        ["0" | _] -> :numeric
        ["1" | _] -> :numeric
        ["smash" | _] -> :text
      end

    votes = Vote.all(where: [session_id: session_id])
    polls = Poll.all(where: [session_id: session_id])

    track_summaries = calculate_track_summaries(session, votes, polls, mode)

    session_summary = %{
      unique_votes: length(votes) + Enum.sum(Enum.map(polls, fn poll -> poll.total_votes end)),
      unique_voters: votes |> Enum.map(fn vote -> vote.viewer_id end) |> Enum.uniq() |> length(),
      viewer_score: calculate_average_score(Enum.map(track_summaries, fn t -> t.viewer_score end), mode),
      streamer_score: calculate_average_score(Enum.map(track_summaries, fn t -> t.streamer_score end), mode),
      tracks_rated: length(track_summaries)
    }

    attrs = %{session_id: session_id, session_summary: session_summary, track_summaries: track_summaries}

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

  defp to_integer(x) when is_integer(x), do: x
  defp to_integer(x) when is_number(x), do: x
  defp to_integer(x) when is_binary(x), do: String.to_integer(x)

  defp calculate_average_score([], _), do: nil

  defp calculate_average_score(votes, :numeric) when is_list(votes) do
    votes = Enum.map(votes, &to_integer/1)
    Float.round(Enum.sum(votes) / length(votes), 1)
  end

  defp calculate_average_score(votes, :text) when is_list(votes) do
    votes
    |> Enum.frequencies()
    |> then(fn frequencies ->
      max_count = frequencies |> Map.values() |> Enum.max()

      frequencies
      |> Enum.filter(fn {_value, count} -> count == max_count end)
      |> Enum.map(fn {value, _count} -> value end)
      |> case do
        [most_frequent] -> most_frequent
        [_ | _] -> "even"
      end
    end)
  end

  defp calculate_track_viewer_score(track_id, votes, polls, vote_options, :numeric) do
    individual_score =
      votes
      |> Enum.filter(fn vote -> vote.track_id == track_id and not vote.is_streamer end)
      |> Enum.map(& &1.value)
      |> calculate_average_score(:numeric)

    poll_scores =
      polls
      |> Enum.filter(fn poll -> poll.track_id == track_id end)
      |> Enum.map(fn poll -> extract_poll_score(poll, vote_options, :numeric) end)

    calculate_average_score(Enum.reject([individual_score] ++ poll_scores, &is_nil/1), :numeric)
  end

  defp calculate_track_viewer_score(track_id, votes, polls, vote_options, :text) do
    individual_result =
      votes
      |> Enum.filter(fn vote -> vote.track_id == track_id and not vote.is_streamer end)
      |> Enum.map(& &1.value)
      |> calculate_average_score(:text)

    poll_results =
      polls
      |> Enum.filter(fn poll -> poll.track_id == track_id end)
      |> Enum.map(fn poll -> extract_poll_score(poll, vote_options, :text) end)
      |> Enum.reject(&is_nil/1)

    calculate_average_score(Enum.reject([individual_result] ++ poll_results, &is_nil/1), :text)
  end

  defp calculate_track_streamer_score(track_id, votes, mode) do
    votes
    |> Enum.filter(fn vote -> vote.track_id == track_id and vote.is_streamer end)
    |> Enum.map(& &1.value)
    |> calculate_average_score(mode)
  end

  defp extract_poll_score(%{total_votes: 0}, _, _), do: nil

  defp extract_poll_score(%{total_votes: total_votes} = poll, vote_options, :numeric) do
    weighted_sum =
      Enum.reduce(vote_options, 0, fn option, acc ->
        acc + String.to_integer(option) * Map.get(poll.votes, option, 0)
      end)

    weighted_sum / total_votes
  end

  defp extract_poll_score(poll, _vote_options, :text) do
    poll.votes
    |> Enum.max_by(fn {_option, count} -> count end, fn -> {nil, 0} end)
    |> case do
      {option, max_count} ->
        poll.votes
        |> Enum.filter(fn {_option, count} -> count == max_count end)
        |> Enum.map(fn {option, _count} -> option end)
        |> length()
        |> case do
          1 -> option
          _ -> "even"
        end

      _ ->
        nil
    end
  end

  defp calculate_track_summaries(%ListeningSession{vote_options: vote_options}, votes, polls, mode) do
    (Enum.map(votes, & &1.track_id) ++ Enum.map(polls, & &1.track_id))
    |> Enum.uniq()
    |> Enum.map(fn track_id ->
      viewer_score = calculate_track_viewer_score(track_id, votes, polls, vote_options, mode)
      streamer_score = calculate_track_streamer_score(track_id, votes, mode)

      track_votes = Enum.filter(votes, fn vote -> vote.track_id == track_id end)
      track_polls = Enum.filter(polls, fn poll -> poll.track_id == track_id end)

      %{
        track_id: track_id,
        viewer_score: viewer_score || if(mode == :numeric, do: 0.0, else: "even"),
        streamer_score: streamer_score || if(mode == :numeric, do: 0.0, else: "even"),
        unique_votes: length(track_votes),
        poll_count: Enum.sum(Enum.map(track_polls, & &1.total_votes)),
        unique_voters: length(Enum.uniq(Enum.map(track_votes, & &1.viewer_id)))
      }
    end)
    |> Enum.sort_by(& &1.track_id)
  end
end
