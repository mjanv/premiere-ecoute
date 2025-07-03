defmodule PremiereEcoute.Sessions.Scores.Report do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Ecto.Adapters.SQL

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.{Pool, Vote}

  @type session_summary :: %{
          viewer_score: float(),
          streamer_score: float(),
          tracks_rated: integer()
        }

  @type track_summary :: %{
          track_id: integer(),
          viewer_score: float(),
          streamer_score: float(),
          individual_count: integer(),
          pool_count: integer(),
          unique_voters: integer()
        }

  @type t :: %__MODULE__{
          id: integer(),
          generated_at: NaiveDateTime.t(),
          unique_votes: integer(),
          unique_voters: integer(),
          session_summary: session_summary(),
          track_summaries: [track_summary()],
          session_id: integer(),
          session: ListeningSession.t(),
          votes: [Vote.t()],
          pools: [Pool.t()],
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "reports" do
    field :generated_at, :naive_datetime
    field :unique_votes, :integer
    field :unique_voters, :integer
    field :session_summary, :map
    field :track_summaries, {:array, :map}

    belongs_to :session, ListeningSession

    has_many :votes, Vote, foreign_key: :session_id, references: :session_id
    has_many :pools, Pool, foreign_key: :session_id, references: :session_id

    timestamps()
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [
      :generated_at,
      :unique_votes,
      :unique_voters,
      :session_summary,
      :track_summaries,
      :session_id
    ])
    |> validate_required([:generated_at, :session_id])
    |> validate_number(:unique_votes, greater_than_or_equal_to: 0)
    |> validate_number(:unique_voters, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:session_id)
  end

  def preload(%__MODULE__{} = report) do
    Repo.preload(report, [:votes, :pools])
  end

  @doc """
  Generates a comprehensive report for a listening session.

  This is the main business logic function that combines all vote sources:
  1. Individual votes (viewers + streamer)
  2. Twitch pools
  3. Calculates unique voter counts and aggregated scores

  ## Examples

      iex> generate(123)
      {:ok, %Report{}}
  """
  @spec generate(ListeningSession.t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def generate(%ListeningSession{id: session_id}) do
    session_stats = calculate_session_stats_sql(session_id)
    track_summaries = calculate_track_summaries_sql(session_id)
    session_summary = calculate_session_summary_sql(session_id)

    attrs = %{
      session_id: session_id,
      generated_at: NaiveDateTime.utc_now(),
      unique_votes: session_stats.unique_votes,
      unique_voters: session_stats.unique_voters,
      session_summary: session_summary,
      track_summaries: track_summaries
    }

    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, report} -> {:ok, preload(report)}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec get_by(Keyword.t()) :: t() | nil
  def get_by(opts) do
    from(r in __MODULE__, where: ^opts)
    |> Repo.one()
    |> preload()
  end

  @spec all(Keyword.t()) :: [t()]
  def all(opts) do
    from(r in __MODULE__,
      where: ^opts,
      order_by: [desc: r.generated_at]
    )
    |> Repo.all()
  end

  # PostgreSQL-based calculation functions using raw SQL for maximum efficiency

  # Calculates session-level statistics using PostgreSQL aggregation
  defp calculate_session_stats_sql(session_id) do
    query = """
    SELECT
      COALESCE(individual_votes, 0) as individual_votes,
      COALESCE(pool_votes, 0) as pool_votes,
      COALESCE(unique_individual_voters, 0) + COALESCE(pool_votes, 0) as unique_voters
    FROM (
      SELECT COUNT(*) as individual_votes
      FROM votes
      WHERE session_id = $1
    ) votes_count
    CROSS JOIN (
      SELECT COALESCE(SUM(total_votes), 0) as pool_votes
      FROM pools
      WHERE session_id = $1
    ) pools_count
    CROSS JOIN (
      SELECT COUNT(DISTINCT viewer_id) as unique_individual_voters
      FROM votes
      WHERE session_id = $1 AND is_streamer = false
    ) unique_count
    """

    result = SQL.query!(Repo, query, [session_id])
    [[individual_votes, pool_votes, unique_voters]] = result.rows

    %{
      unique_votes: individual_votes + pool_votes,
      unique_voters: unique_voters
    }
  end

  # Calculates session summary scores using PostgreSQL aggregation
  defp calculate_session_summary_sql(session_id) do
    # PostgreSQL-compatible query with JSON handling
    query = """
    WITH viewer_individual_avg AS (
      SELECT
        track_id,
        AVG(value::FLOAT) as avg_score
      FROM votes
      WHERE session_id = $1 AND is_streamer = false
      GROUP BY track_id
    ),
    streamer_avg AS (
      SELECT
        AVG(value::FLOAT) as avg_score
      FROM votes
      WHERE session_id = $1 AND is_streamer = true
    ),
    pool_avg AS (
      SELECT
        track_id,
        (
          COALESCE((votes->>'1')::INTEGER, 0) * 1 +
          COALESCE((votes->>'2')::INTEGER, 0) * 2 +
          COALESCE((votes->>'3')::INTEGER, 0) * 3 +
          COALESCE((votes->>'4')::INTEGER, 0) * 4 +
          COALESCE((votes->>'5')::INTEGER, 0) * 5 +
          COALESCE((votes->>'6')::INTEGER, 0) * 6 +
          COALESCE((votes->>'7')::INTEGER, 0) * 7 +
          COALESCE((votes->>'8')::INTEGER, 0) * 8 +
          COALESCE((votes->>'9')::INTEGER, 0) * 9 +
          COALESCE((votes->>'10')::INTEGER, 0) * 10
        )::FLOAT / total_votes::FLOAT as avg_score
      FROM pools
      WHERE session_id = $1
    ),
    combined_viewer_avg AS (
      SELECT
        track_id,
        CASE
          WHEN vi.avg_score IS NOT NULL AND pa.avg_score IS NOT NULL
          THEN (vi.avg_score + pa.avg_score) / 2.0
          WHEN vi.avg_score IS NOT NULL
          THEN vi.avg_score
          WHEN pa.avg_score IS NOT NULL
          THEN pa.avg_score
          ELSE 0.0
        END as track_viewer_score
      FROM (
        SELECT DISTINCT track_id FROM votes WHERE session_id = $1
        UNION
        SELECT DISTINCT track_id FROM pools WHERE session_id = $1
      ) all_tracks
      LEFT JOIN viewer_individual_avg vi USING (track_id)
      LEFT JOIN pool_avg pa USING (track_id)
    ),
    track_count AS (
      SELECT COUNT(DISTINCT track_id) as tracks_rated
      FROM (
        SELECT track_id FROM votes WHERE session_id = $1
        UNION
        SELECT track_id FROM pools WHERE session_id = $1
      ) all_tracks
    )
    SELECT
      COALESCE(AVG(track_viewer_score), 0.0) as viewer_score,
      COALESCE((SELECT avg_score FROM streamer_avg), 0.0) as streamer_score,
      (SELECT tracks_rated FROM track_count) as tracks_rated
    FROM combined_viewer_avg
    """

    result = SQL.query!(Repo, query, [session_id])
    [row] = result.rows
    [viewer_score, streamer_score, tracks_rated] = row

    %{
      viewer_score: viewer_score || 0.0,
      streamer_score: streamer_score || 0.0,
      tracks_rated: tracks_rated || 0
    }
  end

  # Calculates track summaries using PostgreSQL aggregation
  defp calculate_track_summaries_sql(session_id) do
    query = """
    WITH all_tracks AS (
      SELECT DISTINCT track_id FROM votes WHERE session_id = $1
      UNION
      SELECT DISTINCT track_id FROM pools WHERE session_id = $1
    ),
    vote_stats AS (
      SELECT
        track_id,
        COUNT(*) as individual_count,
        AVG(CASE WHEN is_streamer = false THEN value::FLOAT END) as viewer_individual_avg,
        AVG(CASE WHEN is_streamer = true THEN value::FLOAT END) as streamer_avg,
        COUNT(DISTINCT CASE WHEN is_streamer = false THEN viewer_id END) as unique_individual_voters
      FROM votes
      WHERE session_id = $1
      GROUP BY track_id
    ),
    pool_stats AS (
      SELECT
        track_id,
        total_votes as pool_count,
        (
          COALESCE((votes->>'1')::INTEGER, 0) * 1 +
          COALESCE((votes->>'2')::INTEGER, 0) * 2 +
          COALESCE((votes->>'3')::INTEGER, 0) * 3 +
          COALESCE((votes->>'4')::INTEGER, 0) * 4 +
          COALESCE((votes->>'5')::INTEGER, 0) * 5 +
          COALESCE((votes->>'6')::INTEGER, 0) * 6 +
          COALESCE((votes->>'7')::INTEGER, 0) * 7 +
          COALESCE((votes->>'8')::INTEGER, 0) * 8 +
          COALESCE((votes->>'9')::INTEGER, 0) * 9 +
          COALESCE((votes->>'10')::INTEGER, 0) * 10
        )::FLOAT / total_votes::FLOAT as pool_avg
      FROM pools
      WHERE session_id = $1
    )
    SELECT
      t.track_id,
      CASE
        WHEN v.viewer_individual_avg IS NOT NULL AND p.pool_avg IS NOT NULL
        THEN (v.viewer_individual_avg + p.pool_avg) / 2.0
        WHEN v.viewer_individual_avg IS NOT NULL
        THEN v.viewer_individual_avg
        WHEN p.pool_avg IS NOT NULL
        THEN p.pool_avg
        ELSE 0.0
      END as viewer_score,
      COALESCE(v.streamer_avg, 0.0) as streamer_score,
      COALESCE(v.individual_count, 0) as individual_count,
      COALESCE(p.pool_count, 0) as pool_count,
      COALESCE(v.unique_individual_voters, 0) + COALESCE(p.pool_count, 0) as unique_voters
    FROM all_tracks t
    LEFT JOIN vote_stats v USING (track_id)
    LEFT JOIN pool_stats p USING (track_id)
    ORDER BY t.track_id
    """

    result = SQL.query!(Repo, query, [session_id])

    Enum.map(result.rows, fn [
                               track_id,
                               viewer_score,
                               streamer_score,
                               individual_count,
                               pool_count,
                               unique_voters
                             ] ->
      %{
        track_id: track_id,
        viewer_score: viewer_score || 0.0,
        streamer_score: streamer_score || 0.0,
        individual_count: individual_count || 0,
        pool_count: pool_count || 0,
        unique_voters: unique_voters || 0
      }
    end)
  end
end
