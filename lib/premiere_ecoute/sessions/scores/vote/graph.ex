defmodule PremiereEcoute.Sessions.Scores.Vote.Graph do
  @moduledoc """
  # Vote Graph Analytics

  Provides graph-based analytics and visualization data for vote scoring, including rolling averages and statistical computations over time-series voting data.
  """

  alias PremiereEcoute.Repo

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
