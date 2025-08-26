defmodule PremiereEcoute.Sessions.Retrospective.VoteTrends do
  @moduledoc """
  # Vote Graph Analytics

  Provides graph-based analytics and visualization data for vote scoring, including rolling averages and statistical computations over time-series voting data.
  """

  alias PremiereEcoute.Repo

  @doc """
  Computes the distribution of votes for a given session.

  Returns a list of {value, count} tuples.
  Example: [{1, 3}, {2, 10}, {3, 5}]
  """
  def distribution(session_id) do
    """
    SELECT value, COUNT(*) as count
    FROM votes
    WHERE session_id = $1
    GROUP BY value
    ORDER BY value
    """
    |> Repo.query!([session_id])
    |> Map.get(:rows)
    |> Enum.map(fn [value, count] -> {value, count} end)
  end

  @doc """
  Computes the distribution of votes per track for a given session.

  Returns a map of track_id => [{value, count}, ...].

  Example:
      %{
        101 => [{1, 3}, {2, 10}, {3, 5}],
        102 => [{1, 1}, {4, 7}]
      }
  """
  def track_distribution(session_id) do
    """
    SELECT track_id, value, COUNT(*) as count
    FROM votes
    WHERE session_id = $1
    GROUP BY track_id, value
    ORDER BY track_id, value
    """
    |> Repo.query!([session_id])
    |> Map.get(:rows)
    |> Enum.group_by(
      fn [track_id, _value, _count] -> track_id end,
      fn [_track_id, value, count] -> {value, count} end
    )
  end

  # ...

  @doc """
  Computes consensus metrics for each track from its vote distribution.

  For each track, the function applies **Laplace smoothing** (α = 1) to avoid zero-probability bins,
  then calculates:

    * **Mean (μ)** – expected value of the rating distribution.
    * **Variance (σ²)** and **Standard deviation (σ)** – measure of spread around the mean.
    * **Mode share (π)** – maximum probability mass of any rating (tightest cluster).
    * **Entropy (H)** – level of mixedness in votes, with:

        H = - Σ (pᵢ * log(pᵢ))

    * **Consensus score (S)** – ranking metric that combines agreement and positivity:

        S = μ + λ·π - β·σ

      with λ = 2 and β = 1 by default.

  Tracks are sorted by consensus score and returned as a map keyed by track_id.
  """

  def consensus(distribution) when is_list(distribution) do
    %{"1" => consensus} = consensus(%{"1" => distribution})
    consensus
  end

  def consensus(distributions) do
    alpha = 1
    lambda = 2
    beta = 1

    distributions
    |> Enum.map(fn {track_id, dist} ->
      # Laplace smoothing
      dist = Enum.map(dist, fn {k, v} -> {k, v + alpha} end)

      {track_id, dist}
    end)
    |> Enum.map(fn {track_id, dist} ->
      total = Enum.reduce(dist, 0, fn {_v, c}, acc -> acc + c end)
      probs = Enum.map(dist, fn {v, c} -> {v, c / total} end)

      # mean μ = Σ (i * p_i)
      mean = Enum.reduce(probs, 0.0, fn {v, p}, acc -> acc + String.to_integer(v) * p end)

      # variance σ² = Σ ((i - μ)² * p_i)
      variance = Enum.reduce(probs, 0.0, fn {v, p}, acc -> acc + :math.pow(String.to_integer(v) - mean, 2) * p end)

      # mode share π = max(p_i)
      mode_share = Enum.max_by(probs, fn {_v, p} -> p end) |> elem(1)

      # entropy H = - Σ (p_i * log(p_i))
      entropy = Enum.reduce(probs, 0.0, fn {_v, p}, acc -> if p > 0, do: acc - p * :math.log(p), else: acc end)

      # score = μ + λ * π - β * σ
      score = mean + lambda * mode_share - beta * :math.sqrt(variance)

      {track_id, %{variance: variance, entropy: entropy, mode_share: mode_share, mean: mean, score: score}}
    end)
    |> Enum.sort_by(fn {_, %{score: score}} -> score end)
    |> Enum.into(%{})
  end

  @doc """
  Computes a rolling average for votes in a session using SQL window functions.

  Returns a list of {timestamp, average} tuples where each average
  is computed from all votes up to that point in time.
  """
  def rolling_average(session_id, aggregation \\ :vote)

  def rolling_average(session_id, :vote) do
    """
    SELECT
      date_trunc('second', inserted_at)::timestamp(0) as inserted_at,
      ROUND(
        AVG(CAST(value AS NUMERIC)) OVER (
          ORDER BY inserted_at
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 1
      )::float as rolling_avg
    FROM votes
    WHERE session_id = $1
    ORDER BY inserted_at
    """
    |> Repo.query!([session_id])
    |> Map.get(:rows)
    |> Enum.map(fn [timestamp, avg] -> {timestamp, avg} end)
  end

  def rolling_average(session_id, :minute) do
    """
    WITH votes_with_cumulative AS (
      SELECT
        (date_trunc('minute', inserted_at) + INTERVAL '1 minute')::timestamp(0) as minute_boundary,
        CAST(value AS NUMERIC) as vote_value,
        ROW_NUMBER() OVER (ORDER BY inserted_at) as vote_order
      FROM votes
      WHERE session_id = $1
    ),
    minute_aggregates AS (
      SELECT DISTINCT
        minute_boundary,
        MAX(vote_order) OVER (PARTITION BY minute_boundary) as max_vote_in_minute
      FROM votes_with_cumulative
    ),
    minute_rolling_avg AS (
      SELECT
        ma.minute_boundary,
        ROUND(
          (SELECT AVG(vote_value)
           FROM votes_with_cumulative
           WHERE vote_order <= ma.max_vote_in_minute), 1
        )::float as rolling_avg
      FROM minute_aggregates ma
    )
    SELECT minute_boundary, rolling_avg
    FROM minute_rolling_avg
    ORDER BY minute_boundary
    """
    |> Repo.query!([session_id])
    |> Map.get(:rows)
    |> Enum.map(fn [timestamp, avg] -> {timestamp, avg} end)
  end
end
