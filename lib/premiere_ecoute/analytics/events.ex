defmodule PremiereEcoute.Analytics.Events do
  @moduledoc """
  Analytics queries directly on the event store.

  Provides aggregation helpers over the `event_store.events` table.
  Useful for quick operational metrics (e.g. accounts created per month)
  without building read-model projections.
  """

  alias PremiereEcoute.Repo

  @type unit :: :year | :month | :week | :day | :hour
  @type row :: %{required(:period) => DateTime.t(), required(:count) => integer(), optional(atom()) => String.t()}

  @doc """
  Counts events bucketed by a time unit, with optional filtering and grouping.

  The first argument is the event module (or a raw event type string). Pass
  `nil` to aggregate across all event types — useful when scoping by stream.

  ## Options

    * `:fields`  – list of JSONB `data` keys to include as group-by dimensions.
      Each key is extracted as text and added to the SELECT / GROUP BY clause.
    * `:filters` – map of JSONB `data` key → value to restrict rows before
      aggregation. Keys must be atoms or safe identifier strings; values are
      passed as query parameters (no injection risk).
    * `:stream`     – a `stream_uuid` string or a list of `stream_uuid` strings to
      restrict events to one or more streams. When omitted, all streams are included.
    * `:from`       – `%DateTime{}` lower bound (inclusive). Defaults to no lower bound.
    * `:to`         – `%DateTime{}` upper bound (inclusive). Defaults to now.
    * `:fill_gaps`  – when `true`, periods with no events are included with `count: 0`
      instead of being omitted. Requires both `:from` and `:to` to be set.
      Not supported when `:fields` grouping is used.

  ## Examples

      # Accounts created per month
      Analytics.aggregate(AccountCreated, :month)

      # All events in the "accounts" stream per month, regardless of type
      Analytics.aggregate(nil, :month, stream: "accounts")

      # Accounts created per month, broken down by provider
      Analytics.aggregate(AccountAssociated, :month, fields: [:provider])

      # Only Twitch associations, grouped by month
      Analytics.aggregate(AccountAssociated, :month, filters: %{provider: "twitch"})

      # Events from multiple streams
      Analytics.aggregate(nil, :month, stream: ["account-id1", "account-id2"])

      # Accounts created per day in March 2026, with zero-filled gaps
      Analytics.aggregate(AccountCreated, :day,
        from: ~U[2026-03-01 00:00:00Z],
        to:   ~U[2026-03-31 23:59:59Z],
        fill_gaps: true
      )

  Returns a list of maps with a `:period` key (truncated `DateTime`) and a
  `:count` key, plus one key per requested field.
  """
  @spec aggregate(module() | String.t() | nil, unit(), Keyword.t()) :: [row()]
  def aggregate(event_module, unit, opts \\ []) do
    validate_unit!(unit)

    event_type = if event_module, do: event_type_string(event_module)
    fields = Keyword.get(opts, :fields, [])
    filters = Keyword.get(opts, :filters, %{})
    stream = Keyword.get(opts, :stream)
    from_dt = Keyword.get(opts, :from)
    to_dt = Keyword.get(opts, :to)
    fill_gaps = Keyword.get(opts, :fill_gaps, false)

    if fill_gaps && (is_nil(from_dt) || is_nil(to_dt)) do
      raise ArgumentError, ":fill_gaps requires both :from and :to to be set"
    end

    if fill_gaps && fields != [] do
      raise ArgumentError, ":fill_gaps is not supported when :fields grouping is used"
    end

    {sql, params} = build_query(event_type, unit, fields, filters, stream, from_dt, to_dt, fill_gaps)

    %{columns: columns, rows: rows} = Repo.query!(sql, params)

    # AIDEV-NOTE: String.to_existing_atom/1 prevents atom table leaks when
    # arbitrary field names come from callers. Unknown column names raise —
    # callers must ensure field name atoms are declared before calling aggregate.
    column_atoms = Enum.map(columns, &String.to_existing_atom/1)

    Enum.map(rows, fn row ->
      column_atoms
      |> Enum.zip(row)
      |> Map.new()
    end)
  end

  # ---------------------------------------------------------------------------
  # Query builder
  # ---------------------------------------------------------------------------

  # AIDEV-NOTE: Raw SQL is used instead of Ecto.Query because schemaless tables
  # cause Ecto to inject bare column refs into SELECT, which breaks GROUP BY
  # when those columns are not aggregated or grouped.
  # Field names are validated to be safe identifiers (atoms or alphanumeric
  # strings) before interpolation into SQL to prevent injection.
  #
  # All WHERE conditions and their bound params are collected as
  # {sql_fragment, value} pairs, then indexed in one pass to ensure $N
  # placeholders never silently misalign.
  defp build_query(event_type, unit, fields, filters, stream, from_dt, to_dt, fill_gaps) do
    Enum.each(fields, &validate_field!/1)
    Enum.each(Map.keys(filters), &validate_field!/1)

    field_selects = Enum.map(fields, &", e.data->>'#{&1}' AS #{&1}")
    field_groups = Enum.map(fields, &", e.data->>'#{&1}'")

    # Collect all {clause_template, value} pairs. The clause_template is a
    # 1-arity function that receives the final $N index to embed.
    conditions =
      [
        if(event_type, do: {fn i -> "e.event_type = $#{i}" end, event_type}),
        if(stream && is_binary(stream), do: {fn i -> "s.stream_uuid = $#{i}" end, stream}),
        if(stream && is_list(stream), do: {fn i -> "s.stream_uuid = ANY($#{i})" end, stream}),
        if(from_dt, do: {fn i -> "e.created_at >= $#{i}" end, from_dt}),
        if(to_dt, do: {fn i -> "e.created_at <= $#{i}" end, to_dt})
      ] ++
        Enum.map(filters, fn {key, val} -> {fn i -> "e.data->>'#{key}' = $#{i}" end, val} end)

    conditions = Enum.reject(conditions, &is_nil/1)

    # Assign param indices starting at $2 ($1 is reserved for the unit string).
    {where_clauses, extra_params} =
      conditions
      |> Enum.with_index(2)
      |> Enum.map(fn {{clause_fn, val}, idx} -> {clause_fn.(idx), val} end)
      |> Enum.unzip()

    params = [to_string(unit)] ++ extra_params

    stream_join =
      if stream do
        """
        JOIN event_store.stream_events se ON se.event_id = e.event_id
        JOIN event_store.streams s ON s.stream_id = se.stream_id
        """
      else
        ""
      end

    where_sql = if where_clauses == [], do: "", else: "WHERE " <> Enum.join(where_clauses, "\nAND ")

    inner_sql = """
    SELECT
      DATE_TRUNC($1, e.created_at) AS period,
      count(e.event_id) AS count
      #{field_selects}
    FROM event_store.events e
    #{stream_join}
    #{where_sql}
    GROUP BY DATE_TRUNC($1, e.created_at)#{field_groups}
    ORDER BY DATE_TRUNC($1, e.created_at)
    """

    if fill_gaps do
      # AIDEV-NOTE: gap filling wraps the inner query as a CTE and left-joins
      # it against generate_series so periods with no events appear as count=0.
      # from_dt / to_dt are already in params; we reference them by index.
      # The series step is '1 <unit>' cast as interval.
      from_idx = Enum.find_index(extra_params, &(&1 == from_dt)) + 2
      to_idx = Enum.find_index(extra_params, &(&1 == to_dt)) + 2

      sql = """
      WITH aggregated AS (
        #{inner_sql}
      )
      SELECT
        s.period,
        COALESCE(a.count, 0) AS count
      FROM generate_series(
        DATE_TRUNC($1, $#{from_idx}::timestamptz AT TIME ZONE 'UTC'),
        DATE_TRUNC($1, $#{to_idx}::timestamptz AT TIME ZONE 'UTC'),
        ('1 ' || $1)::interval
      ) AS s(period)
      LEFT JOIN aggregated a ON a.period = s.period
      ORDER BY s.period
      """

      {sql, params}
    else
      {inner_sql, params}
    end
  end

  defp validate_field!(field) when is_atom(field), do: :ok

  defp validate_field!(field) when is_binary(field) do
    unless Regex.match?(~r/\A[a-zA-Z_][a-zA-Z0-9_]*\z/, field) do
      raise ArgumentError, "unsafe field name: #{inspect(field)}"
    end
  end

  defp event_type_string(module) when is_atom(module), do: Atom.to_string(module)
  defp event_type_string(string) when is_binary(string), do: string

  defp validate_unit!(unit) when unit in [:year, :month, :week, :day, :hour], do: :ok

  defp validate_unit!(unit),
    do: raise(ArgumentError, "invalid unit #{inspect(unit)}, expected one of :year :month :week :day :hour")
end
