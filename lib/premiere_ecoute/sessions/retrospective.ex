defmodule PremiereEcoute.Sessions.Retrospective do
  @moduledoc """
  Business logic for the streamer dashboard functionality.
  Provides queries and data aggregation for displaying albums listened during time periods.
  """

  import Ecto.Query, warn: false

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Report

  @type time_period :: :month | :year

  @doc """
  Get all albums listened by a specific streamer during a time period.

  ## Parameters

    * `user_id` - The ID of the streamer
    * `period` - Time period to filter by (`:month`, `:year`, `:all_time`)
    * `opts` - Options map with optional keys:
      - `:year` - Specific year to filter by (default: current year)
      - `:month` - Specific month to filter by (1-12, only used when period is `:month`)

  ## Returns

  List of album data with scores and session information, ordered by most recent sessions.

  ## Examples

      # Get albums from current month
      iex> StreamerDashboard.get_albums_by_period(user_id, :month)
      [%{album: %Album{}, global_score: 8.5, session_date: ~U[...], ...}]

      # Get albums from specific year
      iex> StreamerDashboard.get_albums_by_period(user_id, :year, %{year: 2023})
      [%{album: %Album{}, global_score: 7.2, session_date: ~U[...], ...}]
      [...]
  """
  @spec get_albums_by_period(integer(), time_period(), map()) :: [map()]
  def get_albums_by_period(user_id, period, opts \\ %{}) do
    current_date = DateTime.utc_now()
    year = Map.get(opts, :year, current_date.year)
    month = Map.get(opts, :month, current_date.month)

    query =
      from s in ListeningSession,
        join: a in Album,
        on: s.album_id == a.id,
        left_join: r in Report,
        on: s.id == r.session_id,
        where: s.user_id == ^user_id,
        where: s.status == :stopped,
        select: %{session: s, album: a, report: r},
        order_by: [desc: s.started_at]

    case period do
      :month ->
        from s in query,
          where: fragment("EXTRACT(year FROM ?) = ?", s.started_at, ^year),
          where: fragment("EXTRACT(month FROM ?) = ?", s.started_at, ^month)

      :year ->
        from s in query,
          where: fragment("EXTRACT(year FROM ?) = ?", s.started_at, ^year)
    end
    |> Repo.all()
  end

  @doc """
  Get detailed track information for a specific album session.
  Used for the modal display when clicking on an album.
  """
  @spec get_album_session_details(integer()) :: {:ok, map()} | {:error, :not_found}
  def get_album_session_details(session_id) do
    query =
      from s in ListeningSession,
        join: a in Album,
        on: s.album_id == a.id,
        left_join: r in Report,
        on: s.id == r.session_id,
        where: s.id == ^session_id,
        preload: [album: [:tracks], user: [], report: []],
        select: s

    query
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      session ->
        tracks =
          session.report.track_summaries
          |> Enum.map(fn %{"track_id" => id} = track_summary ->
            track = Enum.find(session.album.tracks, &(&1.id == id))
            %{track_album: track, track_summary: track_summary}
          end)

        {:ok, %{session: session, tracks: tracks}}
    end
  end
end
