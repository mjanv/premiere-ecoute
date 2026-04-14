defmodule PremiereEcoute.Analytics.Aggregates do
  @moduledoc """
  Analytics queries over aggregate tables.

  Provides time-based aggregation over any Ecto schema that uses
  `PremiereEcouteCore.Aggregate`. Counts rows bucketed by `inserted_at`,
  with optional filtering and grouping by schema columns.

  Complements `PremiereEcoute.Events.Analytics` for data not tracked via
  event sourcing.
  """

  import Ecto.Query

  alias PremiereEcoute.Repo

  @type unit :: :year | :month | :week | :day | :hour
  @type row :: %{required(:period) => DateTime.t(), required(:count) => integer(), optional(atom()) => term()}

  @doc """
  Counts rows in an aggregate table bucketed by a time unit.

  Aggregates over the `inserted_at` column of the given Ecto schema module.

  ## Options

    * `:field`    – an atom column name to group by in addition to the time period.
    * `:filters`  – keyword list of `{column_atom, value}` pairs to restrict rows
      before aggregation. Values are passed as query parameters (no injection risk).
    * `:from`     – `%DateTime{}` lower bound on `inserted_at` (inclusive).
    * `:to`       – `%DateTime{}` upper bound on `inserted_at` (inclusive).
    * `:fill_gaps` – when `true`, periods with no rows are included with `count: 0`.
      Requires both `:from` and `:to`. Not supported when `:field` grouping is used.

  ## Examples

      # Users created per month
      Analytics.aggregate(User, :month)

      # Notifications sent per day in March 2026
      Analytics.aggregate(Notification, :day,
        from: ~U[2026-03-01 00:00:00Z],
        to:   ~U[2026-03-31 23:59:59Z]
      )

      # Notifications per month, broken down by type
      Analytics.aggregate(Notification, :month, field: :type)

      # Only account_created notifications
      Analytics.aggregate(Notification, :month, filters: [type: "account_created"])

      # Votes per day with zero-filled gaps
      Analytics.aggregate(Vote, :day,
        from: ~U[2026-01-01 00:00:00Z],
        to:   ~U[2026-01-31 23:59:59Z],
        fill_gaps: true
      )

  Returns a list of maps with a `:period` key (`DateTime`) and a `:count` key,
  plus a key for `:field` when grouping is requested.
  """
  @spec aggregate(module(), unit(), Keyword.t()) :: [row()]
  def aggregate(schema, unit, opts \\ []) do
    validate_unit!(unit)

    field = Keyword.get(opts, :field)
    filters = Keyword.get(opts, :filters, [])
    from_dt = Keyword.get(opts, :from)
    to_dt = Keyword.get(opts, :to)
    fill_gaps = Keyword.get(opts, :fill_gaps, false)

    if fill_gaps && (is_nil(from_dt) || is_nil(to_dt)) do
      raise ArgumentError, ":fill_gaps requires both :from and :to to be set"
    end

    if fill_gaps && field != nil do
      raise ArgumentError, ":fill_gaps is not supported when :field grouping is used"
    end

    unit_str = to_string(unit)

    base =
      schema
      |> apply_filters(filters)
      |> apply_range(from_dt, to_dt)

    if fill_gaps do
      aggregate_with_gaps(base, unit_str, from_dt, to_dt)
    else
      aggregate_plain(base, unit_str, field)
    end
  end

  # ---------------------------------------------------------------------------
  # Query helpers
  # ---------------------------------------------------------------------------

  defp apply_filters(query, []), do: query

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, q ->
      where(q, [r], field(r, ^key) == ^value)
    end)
  end

  defp apply_range(query, nil, nil), do: query
  defp apply_range(query, from_dt, nil), do: where(query, [r], r.inserted_at >= ^from_dt)
  defp apply_range(query, nil, to_dt), do: where(query, [r], r.inserted_at <= ^to_dt)

  defp apply_range(query, from_dt, to_dt),
    do: where(query, [r], r.inserted_at >= ^from_dt and r.inserted_at <= ^to_dt)

  defp aggregate_plain(base, unit_str, nil) do
    # AIDEV-NOTE: selected_as/group_by(:period) ensures a single DATE_TRUNC
    # expression is emitted in the SELECT and referenced by alias in GROUP BY
    # and ORDER BY, avoiding Ecto's multi-param duplication bug where each
    # fragment occurrence gets its own $N placeholder and Postgres rejects the
    # query with "must appear in the GROUP BY clause".
    # NaiveDateTime is returned by DATE_TRUNC on utc_datetime columns via Ecto
    # fragment, so we normalize to UTC DateTime after the query.
    base
    |> select([r], %{
      period: selected_as(fragment("DATE_TRUNC(?, ?)", ^unit_str, r.inserted_at), :period),
      count: count(r.id)
    })
    |> group_by([], selected_as(:period))
    |> order_by([], selected_as(:period))
    |> Repo.all()
    |> Enum.map(&normalize_period/1)
  end

  defp aggregate_plain(base, unit_str, field) do
    base
    |> select([r], %{
      period: selected_as(fragment("DATE_TRUNC(?, ?)", ^unit_str, r.inserted_at), :period),
      count: count(r.id),
      field_value: field(r, ^field)
    })
    |> group_by([r], [selected_as(:period), field(r, ^field)])
    |> order_by([], selected_as(:period))
    |> Repo.all()
    # AIDEV-NOTE: Rename :field_value to the caller's chosen field atom so the
    # returned maps use the same key name as the schema column.
    |> Enum.map(fn row ->
      row
      |> normalize_period()
      |> Map.delete(:field_value)
      |> Map.put(field, row.field_value)
    end)
  end

  defp aggregate_with_gaps(base, unit_str, from_dt, to_dt) do
    # AIDEV-NOTE: gap filling uses raw SQL because Ecto cannot select a scalar
    # value directly from a fragment source (generate_series). The inner
    # aggregation is expressed as an Ecto subquery and inlined as SQL via
    # Repo.to_sql, then joined against the series in a hand-written CTE.
    # NaiveDateTime normalization is applied post-query as with aggregate_plain.
    inner =
      base
      |> select([r], %{
        period: selected_as(fragment("DATE_TRUNC(?, ?)", ^unit_str, r.inserted_at), :period),
        count: count(r.id)
      })
      |> group_by([], selected_as(:period))

    {inner_sql, inner_params} = Repo.to_sql(:all, inner)

    # generate_series params are appended after the inner query's params.
    # $1 in the outer query references the first extra param (unit_str is
    # already embedded in inner_sql via inner_params).
    n = length(inner_params)

    sql = """
    WITH aggregated AS (#{inner_sql})
    SELECT
      s.period,
      COALESCE(a.count, 0) AS count
    FROM generate_series(
      DATE_TRUNC($#{n + 3}, $#{n + 1}::timestamptz AT TIME ZONE 'UTC'),
      DATE_TRUNC($#{n + 3}, $#{n + 2}::timestamptz AT TIME ZONE 'UTC'),
      ('1 ' || $#{n + 3})::interval
    ) AS s(period)
    LEFT JOIN aggregated a ON a.period = s.period
    ORDER BY s.period
    """

    params = inner_params ++ [from_dt, to_dt, unit_str]

    %{columns: columns, rows: rows} = Repo.query!(sql, params)
    column_atoms = Enum.map(columns, &String.to_existing_atom/1)

    rows
    |> Enum.map(fn row -> column_atoms |> Enum.zip(row) |> Map.new() end)
    |> Enum.map(&normalize_period/1)
  end

  # DATE_TRUNC via Ecto fragment returns NaiveDateTime on utc_datetime columns.
  # Normalize to UTC DateTime so callers get a consistent type.
  defp normalize_period(%{period: %NaiveDateTime{} = ndt} = row),
    do: %{row | period: DateTime.from_naive!(ndt, "Etc/UTC")}

  defp normalize_period(row), do: row

  defp validate_unit!(unit) when unit in [:year, :month, :week, :day, :hour], do: :ok

  defp validate_unit!(unit),
    do: raise(ArgumentError, "invalid unit #{inspect(unit)}, expected one of :year :month :week :day :hour")
end
