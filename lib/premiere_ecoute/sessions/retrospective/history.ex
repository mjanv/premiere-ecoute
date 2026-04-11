defmodule PremiereEcoute.Sessions.Retrospective.History do
  @moduledoc """
  Business logic for the streamer dashboard functionality.
  Provides queries and data aggregation for displaying albums listened during time periods.
  """

  import Ecto.Query, warn: false

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track, as: PlaylistTrack
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Discography.SingleArtist
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Scores.Vote

  @type time_period :: :all | :month | :year

  @doc """
  Get all albums listened by a specific streamer during a time period.
  """
  @spec get_albums_by_period(User.t(), time_period(), map()) :: [map()]
  def get_albums_by_period(%User{id: user_id} = user, period, opts \\ %{}) do
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
    |> Enum.map(fn item -> %{item | session: %{item.session | user: user}} end)
  end

  @doc """
  Get all single-track sessions listened by a specific streamer during a time period.
  """
  @spec get_singles_by_period(User.t(), time_period(), map()) :: [map()]
  def get_singles_by_period(%User{id: user_id} = user, period, opts \\ %{}) do
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
    |> Enum.map(fn item -> %{item | session: %{item.session | user: user}} end)
  end

  @doc """
  Get all playlist sessions listened by a specific streamer during a time period.
  """
  @spec get_playlists_by_period(User.t(), time_period(), map()) :: [map()]
  def get_playlists_by_period(%User{id: user_id} = user, period, opts \\ %{}) do
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
    |> Enum.map(fn item -> %{item | session: %{item.session | user: user}} end)
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
        join: u in User,
        on: u.id == s.user_id,
        where: v.viewer_id == ^user_id,
        where: v.value not in ["smash", "pass"],
        group_by: [s.id, s.share_token, u.username, a.id, a.name, a.cover_url],
        select: %{
          session_id: s.id,
          share_token: s.share_token,
          username: u.username,
          album: %Album{
            id: a.id,
            name: a.name,
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
  Get all votes casted on singles by a specific viewer during a time period.
  """
  @spec get_single_votes_by_period(User.t(), time_period(), map()) :: [map()]
  def get_single_votes_by_period(%User{twitch: %{user_id: user_id}}, period, opts \\ %{}) do
    current_date = DateTime.utc_now()
    year = Map.get(opts, :year, current_date.year)
    month = Map.get(opts, :month, current_date.month)

    query =
      from v in Vote,
        join: s in ListeningSession,
        on: v.session_id == s.id,
        join: sg in Single,
        on: s.single_id == sg.id,
        left_join: sa in SingleArtist,
        on: sa.single_id == sg.id,
        left_join: ar in Artist,
        on: ar.id == sa.artist_id,
        join: u in User,
        on: u.id == s.user_id,
        where: v.viewer_id == ^user_id,
        where: v.value not in ["smash", "pass"],
        group_by: [s.id, s.share_token, u.username, sg.id, sg.name, sg.cover_url, ar.name],
        select: %{
          session_id: s.id,
          share_token: s.share_token,
          username: u.username,
          single: %Single{
            id: sg.id,
            name: sg.name,
            cover_url: sg.cover_url,
            artist: ar.name
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
  Get all votes casted on playlist tracks by a specific viewer during a time period.
  """
  @spec get_playlist_votes_by_period(User.t(), time_period(), map()) :: [map()]
  def get_playlist_votes_by_period(%User{twitch: %{user_id: user_id}}, period, opts \\ %{}) do
    current_date = DateTime.utc_now()
    year = Map.get(opts, :year, current_date.year)
    month = Map.get(opts, :month, current_date.month)

    query =
      from v in Vote,
        join: s in ListeningSession,
        on: v.session_id == s.id,
        join: p in Playlist,
        on: s.playlist_id == p.id,
        join: u in User,
        on: u.id == s.user_id,
        where: v.viewer_id == ^user_id,
        where: v.value not in ["smash", "pass"],
        group_by: [s.id, s.share_token, u.username, p.id, p.title, p.owner_name, p.cover_url],
        select: %{
          session_id: s.id,
          share_token: s.share_token,
          username: u.username,
          playlist: %Playlist{
            id: p.id,
            title: p.title,
            owner_name: p.owner_name,
            cover_url: p.cover_url
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
  Get top singles voted by a viewer during a time period, sorted by vote score descending.
  """
  @spec get_top_singles_by_period(User.t(), time_period(), map()) :: [map()]
  def get_top_singles_by_period(%User{twitch: %{user_id: user_id}}, period, opts \\ %{}) do
    current_date = DateTime.utc_now()
    year = Map.get(opts, :year, current_date.year)
    month = Map.get(opts, :month, current_date.month)

    query =
      from v in Vote,
        join: s in ListeningSession,
        on: v.session_id == s.id,
        join: sg in Single,
        on: s.single_id == sg.id,
        left_join: sa in SingleArtist,
        on: sa.single_id == sg.id,
        left_join: ar in Artist,
        on: ar.id == sa.artist_id,
        where: v.viewer_id == ^user_id,
        where: fragment("? ~ '^[0-9]+$'", v.value),
        select: %{
          single: %Single{
            id: sg.id,
            name: sg.name,
            artist: ar.name,
            cover_url: sg.cover_url,
            duration_ms: sg.duration_ms
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
  Get top playlist tracks voted by a viewer during a time period, sorted by vote score descending.
  """
  @spec get_top_playlist_tracks_by_period(User.t(), time_period(), map()) :: [map()]
  def get_top_playlist_tracks_by_period(%User{twitch: %{user_id: user_id}}, period, opts \\ %{}) do
    current_date = DateTime.utc_now()
    year = Map.get(opts, :year, current_date.year)
    month = Map.get(opts, :month, current_date.month)

    query =
      from v in Vote,
        join: s in ListeningSession,
        on: v.session_id == s.id,
        join: p in Playlist,
        on: s.playlist_id == p.id,
        join: pt in PlaylistTrack,
        on: pt.playlist_id == p.id and pt.id == v.track_id,
        where: v.viewer_id == ^user_id,
        where: fragment("? ~ '^[0-9]+$'", v.value),
        select: %{
          track: %PlaylistTrack{
            id: pt.id,
            name: pt.name,
            artist: pt.artist,
            duration_ms: pt.duration_ms,
            playlist_id: pt.playlist_id,
            playlist: %Playlist{
              id: p.id,
              title: p.title,
              owner_name: p.owner_name,
              cover_url: p.cover_url
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
  Get detailed track information for a specific album session.
  """
  @spec get_album_session_details(integer()) :: {:ok, map()} | {:error, :not_found}
  def get_album_session_details(session_id) do
    query =
      from s in ListeningSession,
        join: a in Album,
        on: s.album_id == a.id,
        where: s.id == ^session_id,
        preload: [album: [:tracks], user: []],
        select: s

    query
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      session ->
        {:ok, report} = Report.generate(session)

        tracks =
          report.track_summaries
          |> Enum.map(fn track_summary ->
            id = track_summary[:track_id] || track_summary["track_id"]
            track = Enum.find(session.album.tracks, &(&1.id == id))
            %{track_album: track, track_summary: track_summary}
          end)

        {:ok, %{session: %{session | report: report}, tracks: tracks}}
    end
  end

  @doc """
  Get detailed information for a specific single-track session.
  """
  @spec get_single_session_details(integer()) :: {:ok, map()} | {:error, :not_found}
  def get_single_session_details(session_id) do
    query =
      from s in ListeningSession,
        join: sg in Single,
        on: s.single_id == sg.id,
        where: s.id == ^session_id,
        preload: [user: []],
        select: {s, sg}

    query
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      {session, single} ->
        {:ok, report} = Report.generate(session)
        {:ok, %{session: %{session | report: report}, single: single}}
    end
  end

  @doc """
  Get detailed information for a specific playlist session.
  """
  @spec get_playlist_session_details(integer()) :: {:ok, map()} | {:error, :not_found}
  def get_playlist_session_details(session_id) do
    query =
      from s in ListeningSession,
        join: p in Playlist,
        on: s.playlist_id == p.id,
        where: s.id == ^session_id,
        preload: [user: []],
        select: {s, p}

    query
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      {session, playlist} ->
        playlist = Repo.preload(playlist, :tracks)
        {:ok, report} = Report.generate(session)

        tracks =
          report.track_summaries
          |> Enum.map(fn track_summary ->
            id = track_summary[:track_id] || track_summary["track_id"]
            track = Enum.find(playlist.tracks, &(&1.id == id))
            %{playlist_track: track, track_summary: track_summary}
          end)

        {:ok, %{session: %{session | report: report}, playlist: playlist, tracks: tracks}}
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
        group_by: [t.id, t.name, t.album_id, a.name],
        # on calcule le score moyen pour le ORDER BY uniquement
        select: %Album.Track{
          id: t.id,
          name: t.name,
          album_id: t.album_id,
          track_id: t.track_id,
          album: %Album{
            name: a.name
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
