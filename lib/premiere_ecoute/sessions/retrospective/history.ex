defmodule PremiereEcoute.Sessions.Retrospective.History do
  @moduledoc """
  Business logic for the streamer dashboard functionality.
  Provides queries and data aggregation for displaying albums listened during time periods.
  """

  import Ecto.Query, warn: false

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Scores.Vote

  @type time_period :: :all | :month | :year

  @doc """
  Get all albums listened by a specific streamer during a time period.
  """
  @spec get_albums_by_period(User.t(), time_period(), map()) :: [map()]
  def get_albums_by_period(%User{id: user_id}, period, opts \\ %{}) do
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
  Get all single-track sessions listened by a specific streamer during a time period.
  """
  @spec get_singles_by_period(User.t(), time_period(), map()) :: [map()]
  def get_singles_by_period(%User{id: user_id}, period, opts \\ %{}) do
    current_date = DateTime.utc_now()
    year = Map.get(opts, :year, current_date.year)
    month = Map.get(opts, :month, current_date.month)

    query =
      from s in ListeningSession,
        join: sg in Single,
        on: s.single_id == sg.id,
        left_join: r in Report,
        on: s.id == r.session_id,
        where: s.user_id == ^user_id,
        where: s.status == :stopped,
        where: s.source == :track,
        select: %{session: s, single: sg, report: r},
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
  Get all playlist sessions listened by a specific streamer during a time period.
  """
  @spec get_playlists_by_period(User.t(), time_period(), map()) :: [map()]
  def get_playlists_by_period(%User{id: user_id}, period, opts \\ %{}) do
    current_date = DateTime.utc_now()
    year = Map.get(opts, :year, current_date.year)
    month = Map.get(opts, :month, current_date.month)

    query =
      from s in ListeningSession,
        join: p in Playlist,
        on: s.playlist_id == p.id,
        left_join: r in Report,
        on: s.id == r.session_id,
        where: s.user_id == ^user_id,
        where: s.status == :stopped,
        where: s.source == :playlist,
        select: %{session: s, playlist: p, report: r},
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
  Get all votes casted by a specific viewer during a time period.
  """
  @spec get_votes_by_period(User.t(), time_period(), map()) :: [map()]
  def get_votes_by_period(%User{twitch: %{user_id: user_id}}, period, opts \\ %{}) do
    current_date = DateTime.utc_now()
    year = Map.get(opts, :year, current_date.year)
    month = Map.get(opts, :month, current_date.month)

    query =
      from v in Vote,
        join: s in ListeningSession,
        on: v.session_id == s.id,
        join: a in Album,
        on: s.album_id == a.id,
        where: v.viewer_id == ^user_id,
        where: v.value not in ["smash", "pass"],
        group_by: [a.id, a.name, a.artist, a.cover_url],
        select: %{
          album: %Album{
            id: a.id,
            name: a.name,
            artist: a.artist,
            cover_url: a.cover_url
          },
          score: fragment("ROUND(AVG(CAST(? AS DECIMAL)), 1)", v.value)
        },
        order_by: [desc: count(v.id)]

    case period do
      :month ->
        from s in query,
          where: fragment("EXTRACT(year FROM ?) = ?", s.inserted_at, ^year),
          where: fragment("EXTRACT(month FROM ?) = ?", s.inserted_at, ^month)

      :year ->
        from s in query,
          where: fragment("EXTRACT(year FROM ?) = ?", s.inserted_at, ^year)
    end
    |> Repo.all()
  end

  @doc """
  Get detailed track information for a specific album session.
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

  @doc """
  Get top tracks voted by a viewer during a time period, sorted by vote score descending.
  Returns a list of maps with a typed Track struct (with nested Album), the score string, and the vote timestamp.
  Excludes non-numeric votes (smash/pass). Limited to 10 results.
  """
  @spec get_top_tracks_by_period(User.t(), time_period(), map()) :: [map()]
  def get_top_tracks_by_period(%User{twitch: %{user_id: user_id}}, period, opts \\ %{}) do
    current_date = DateTime.utc_now()
    year = Map.get(opts, :year, current_date.year)
    month = Map.get(opts, :month, current_date.month)

    query =
      from v in Vote,
        join: s in ListeningSession,
        on: v.session_id == s.id,
        join: a in Album,
        on: s.album_id == a.id,
        join: t in Album.Track,
        on: t.album_id == a.id and t.id == v.track_id,
        where: v.viewer_id == ^user_id,
        where: fragment("? ~ '^[0-9]+$'", v.value),
        select: %{
          track: %Album.Track{
            id: t.id,
            name: t.name,
            track_number: t.track_number,
            duration_ms: t.duration_ms,
            album_id: t.album_id,
            album: %Album{
              id: a.id,
              name: a.name,
              artist: a.artist,
              cover_url: a.cover_url
            }
          },
          score: v.value,
          voted_at: v.inserted_at
        },
        order_by: [
          desc: fragment("CAST(? AS DECIMAL)", v.value),
          desc: v.inserted_at
        ],
        limit: 10

    case period do
      :all ->
        query

      :month ->
        from v in query,
          where: fragment("EXTRACT(year FROM ?) = ?", v.inserted_at, ^year),
          where: fragment("EXTRACT(month FROM ?) = ?", v.inserted_at, ^month)

      :year ->
        from v in query,
          where: fragment("EXTRACT(year FROM ?) = ?", v.inserted_at, ^year)
    end
    |> Repo.all()
  end

  @doc """
  Get all albums listened by a specific viewer during a time period.
  """
  @spec get_tracks_by_period(integer(), integer(), time_period(), map()) :: [map()]
  def get_tracks_by_period(user_id, n, period, opts \\ %{}) do
    current_date = DateTime.utc_now()
    year = Map.get(opts, :year, current_date.year)
    month = Map.get(opts, :month, current_date.month)

    query =
      from v in Vote,
        join: s in ListeningSession,
        on: v.session_id == s.id,
        join: a in Album,
        on: s.album_id == a.id,
        join: t in Album.Track,
        on: t.album_id == a.id and t.id == v.track_id,
        where: v.viewer_id == ^user_id,
        where: fragment("? ~ '^[0-9]+$'", v.value),
        group_by: [t.id, t.name, t.album_id, a.name, a.artist],
        # on calcule le score moyen pour le ORDER BY uniquement
        select: %Album.Track{
          id: t.id,
          name: t.name,
          album_id: t.album_id,
          track_id: t.track_id,
          album: %Album{
            name: a.name,
            artist: a.artist
          }
        },
        order_by: [desc: fragment("AVG(CAST(? AS DECIMAL))", v.value)],
        limit: ^n

    case period do
      :month ->
        from s in query,
          where: fragment("EXTRACT(year FROM ?) = ?", s.inserted_at, ^year),
          where: fragment("EXTRACT(month FROM ?) = ?", s.inserted_at, ^month)

      :year ->
        from s in query,
          where: fragment("EXTRACT(year FROM ?) = ?", s.inserted_at, ^year)
    end
    |> Repo.all()
  end
end
