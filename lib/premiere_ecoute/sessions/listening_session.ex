defmodule PremiereEcoute.Sessions.ListeningSession do
  @moduledoc """
  Listening session aggregate.

  Manages album and playlist listening sessions with status transitions (preparing/active/stopped), track navigation and markers, visibility controls (private/protected/public), vote tracking, and retrospective access control.
  """

  use PremiereEcouteCore.Aggregate,
    root: [
      user: [:twitch, :spotify],
      album: [:tracks],
      current_track: [],
      playlist: [:tracks],
      current_playlist_track: [],
      track_markers: []
    ],
    json: [:id, :status, :started_at, :ended_at, :user, :album, :current_track, :playlist]

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Follow
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession.TrackMarker
  alias PremiereEcoute.Sessions.Retrospective.Report

  @type t :: %__MODULE__{
          id: integer() | nil,
          status: atom(),
          visibility: atom(),
          started_at: DateTime.t() | nil,
          ended_at: DateTime.t() | nil,
          user: entity(User.t()),
          album: entity(Album.t()),
          current_track: entity(Album.Track.t()),
          playlist: entity(Playlist.t()),
          report: entity(Report.t()),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "listening_sessions" do
    field :status, Ecto.Enum, values: [:preparing, :active, :stopped], default: :preparing
    field :source, Ecto.Enum, values: [:album, :playlist], default: :album
    field :visibility, Ecto.Enum, values: [:private, :protected, :public], default: :protected
    field :options, :map, default: %{"votes" => 0, "scores" => 0, "next_track" => 0}
    field :vote_options, {:array, :string}, default: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    belongs_to :user, User, foreign_key: :user_id

    belongs_to :album, Album, foreign_key: :album_id
    belongs_to :current_track, Album.Track, foreign_key: :current_track_id

    belongs_to :playlist, Playlist, foreign_key: :playlist_id
    belongs_to :current_playlist_track, Playlist.Track, foreign_key: :current_playlist_track_id

    has_one :report, Report, foreign_key: :session_id
    has_many :track_markers, TrackMarker, foreign_key: :listening_session_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates changeset for listening session.

  Validates and casts session attributes including status, source, visibility, options, vote options, timestamps, and foreign keys.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(listening_session, attrs) do
    listening_session
    |> cast(attrs, [
      :status,
      :source,
      :visibility,
      :options,
      :vote_options,
      :started_at,
      :ended_at,
      :user_id,
      :album_id,
      :current_track_id,
      :playlist_id,
      :current_playlist_track_id
    ])
    |> validate_required([])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:album_id)
    |> foreign_key_constraint(:current_track_id)
    |> foreign_key_constraint(:current_playlist_track_id)
  end

  @doc """
  Starts a listening session.

  Transitions session from preparing to active status, sets started timestamp, and ensures user has no other active sessions.
  """
  @spec start(t()) :: {:ok, t()} | {:error, atom() | Ecto.Changeset.t()}
  def start(%__MODULE__{id: session_id, user_id: user_id} = session) do
    case has_active_session?(user_id, session_id) do
      true ->
        {:error, :active_session_exists}

      false ->
        session
        |> change()
        |> put_change(:status, :active)
        |> put_change(:started_at, DateTime.utc_now(:second))
        |> Repo.update()
    end
  end

  @doc """
  Stops an active listening session.

  Transitions session to stopped status, sets ended timestamp, and clears current track. Returns error if session is not active.
  """
  @spec stop(t()) :: {:ok, t()} | {:error, atom() | Ecto.Changeset.t()}
  def stop(%__MODULE__{status: :active} = session) do
    session
    |> change()
    |> put_change(:status, :stopped)
    |> put_change(:ended_at, DateTime.utc_now(:second))
    |> put_change(:current_track_id, nil)
    |> Repo.update()
    |> case do
      {:ok, session} -> {:ok, Repo.preload(session, current_track: [])}
      {:error, reason} -> {:error, reason}
    end
  end

  def stop(%__MODULE__{} = _session) do
    {:error, :invalid_status}
  end

  @doc """
  Creates a track marker recording when the current track started playing.
  """
  @spec add_track_marker(t()) :: {:ok, TrackMarker.t()} | {:error, Ecto.Changeset.t() | atom()}
  def add_track_marker(%__MODULE__{source: :album, current_track: track} = session)
      when not is_nil(track) do
    %TrackMarker{}
    |> TrackMarker.changeset(%{
      listening_session_id: session.id,
      track_id: track.id,
      track_number: track.track_number,
      started_at: DateTime.utc_now(:second)
    })
    |> Repo.insert()
  end

  def add_track_marker(%__MODULE__{source: :playlist, current_playlist_track: track, playlist: playlist} = session)
      when not is_nil(track) do
    # Calculate track position based on its order in the playlist
    track_number =
      playlist.tracks
      |> Enum.find_index(&(&1.id == track.id))
      |> case do
        nil -> 1
        index -> index + 1
      end

    %TrackMarker{}
    |> TrackMarker.changeset(%{
      listening_session_id: session.id,
      track_id: track.id,
      track_number: track_number,
      started_at: DateTime.utc_now(:second)
    })
    |> Repo.insert()
  end

  def add_track_marker(%__MODULE__{} = _session) do
    {:error, :no_current_track}
  end

  @doc """
  Advances to the next track in the session.

  For albums, moves to the next track by track number. For playlists, uses track order. Returns error if no more tracks available.
  """
  @spec next_track(t()) :: {:ok, t()} | {:error, atom() | Ecto.Changeset.t()}
  def next_track(%__MODULE__{source: :playlist} = session) do
    %{playlist: %{tracks: tracks}} = Repo.preload(session, playlist: [:tracks], current_playlist_track: [])
    current_track(session, hd(Enum.reverse(tracks)).id)
  end

  def next_track(%__MODULE__{source: :album} = session) do
    session = Repo.preload(session, album: [:tracks], current_track: [])
    tracks = Enum.sort_by(session.album.tracks, & &1.track_number)

    session.current_track
    |> case do
      nil ->
        hd(tracks).id

      current_track ->
        current_index = Enum.find_index(tracks, &(&1.id == current_track.id))

        if current_index == length(tracks) - 1 do
          nil
        else
          Enum.at(tracks, current_index + 1).id
        end
    end
    |> case do
      nil -> {:error, :no_tracks_left}
      track_id -> current_track(session, track_id)
    end
  end

  @doc """
  Returns to the previous track in the album session.

  Moves to the previous track by track number. Returns error if at first track or no previous track available.
  """
  @spec previous_track(t()) :: {:ok, t()} | {:error, atom() | Ecto.Changeset.t()}
  def previous_track(%__MODULE__{source: :album} = session) do
    session = Repo.preload(session, album: [:tracks], current_track: [])
    tracks = Enum.sort_by(session.album.tracks, & &1.track_number)

    session.current_track
    |> case do
      nil ->
        nil

      current_track ->
        current_index = Enum.find_index(tracks, &(&1.id == current_track.id))

        if current_index == 0 do
          nil
        else
          Enum.at(tracks, current_index - 1).id
        end
    end
    |> case do
      nil -> {:error, :no_tracks_left}
      track_id -> current_track(session, track_id)
    end
  end

  @doc """
  Sets the current track for the session.

  Updates the current track ID for album or playlist sessions and reloads associations.
  """
  @spec current_track(t(), integer()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def current_track(%__MODULE__{source: :album} = session, track_id) do
    session
    |> change()
    |> put_change(:current_track_id, track_id)
    |> Repo.update()
    |> case do
      {:ok, session} -> {:ok, preload(session)}
      {:error, reason} -> {:error, reason}
    end
  end

  def current_track(%__MODULE__{source: :playlist} = session, track_id) do
    session
    |> change()
    |> put_change(:current_playlist_track_id, track_id)
    |> Repo.update()
    |> case do
      {:ok, session} -> {:ok, preload(session)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Retrieves active sessions from followed streamers.

  Returns all active listening sessions for streamers that the user follows.
  """
  @spec active_sessions(User.t()) :: [t()]
  def active_sessions(user) do
    from(s in __MODULE__,
      where: s.status == :active,
      join: f in Follow,
      on: f.streamer_id == s.user_id,
      where: f.user_id == ^user.id
    )
    |> Repo.all()
    |> preload()
  end

  @doc """
  Retrieves user's current session.

  Returns the most recent active or preparing session for the user, prioritizing active sessions.
  """
  @spec current_session(User.t() | nil) :: t() | nil
  def current_session(nil), do: nil

  def current_session(user) do
    from(s in __MODULE__,
      where: s.user_id == ^user.id and s.status in [:active, :preparing],
      order_by: [
        fragment(
          "CASE WHEN ? = 'active' THEN 0 WHEN ? = 'preparing' THEN 1 END",
          s.status,
          s.status
        ),
        desc: s.updated_at
      ],
      limit: 1
    )
    |> Repo.one()
    |> preload()
  end

  @doc """
  Retrieves user's active session.

  Returns the most recent active session for the user, or nil if no active session exists.
  """
  @spec get_active_session(User.t() | nil) :: t() | nil
  def get_active_session(nil), do: nil

  def get_active_session(%User{id: user_id}) do
    from(s in __MODULE__,
      where: s.user_id == ^user_id and s.status == :active,
      order_by: [desc: s.updated_at],
      limit: 1
    )
    |> Repo.one()
    |> preload()
  end

  @doc """
  Returns the session's title.

  Extracts title from album name or playlist title depending on session source.
  """
  @spec title(t()) :: String.t()
  def title(%__MODULE__{album: nil, playlist: nil}), do: ""
  def title(%__MODULE__{album: %{name: name}, playlist: nil}), do: name
  def title(%__MODULE__{album: nil, playlist: %{title: title}}), do: title

  @doc """
  Returns the current track being played.

  Retrieves the current track from either album or playlist source.
  """
  @spec current_track(t()) :: Album.Track.t() | Playlist.Track.t() | nil
  def current_track(%__MODULE__{current_track: nil, current_playlist_track: nil}), do: nil
  def current_track(%__MODULE__{current_track: track, current_playlist_track: nil}), do: track
  def current_track(%__MODULE__{current_track: nil, current_playlist_track: track}), do: track

  @doc """
  Checks if track is currently playing in session.

  Compares track ID with session's current track ID for either album or playlist source.
  """
  @spec current?(t(), Album.Track.t() | Playlist.Track.t()) :: boolean()
  def current?(%__MODULE__{source: :album, current_track: %{id: id}}, %{id: id}), do: true
  def current?(%__MODULE__{source: :playlist, current_playlist_track: %{id: id}}, %{id: id}), do: true
  def current?(_, _), do: false

  @doc """
  Checks if session has a track currently playing.

  Returns true if session has a current track set for either album or playlist source.
  """
  @spec playing?(t()) :: boolean()
  def playing?(%__MODULE__{source: :album, current_track: nil}), do: false
  def playing?(%__MODULE__{source: :playlist, current_playlist_track: nil}), do: false
  def playing?(%__MODULE__{}), do: true

  @doc """
  Returns all tracks in the session.

  Retrieves track list from either album or playlist depending on session source.
  """
  @spec tracks(t()) :: [Album.Track.t()] | [Playlist.Track.t()]
  def tracks(%__MODULE__{album: nil, playlist: nil}), do: []
  def tracks(%__MODULE__{album: %{tracks: tracks}, playlist: nil}), do: tracks
  def tracks(%__MODULE__{album: nil, playlist: %{tracks: tracks}}), do: tracks

  @doc """
  Calculates total duration of session in minutes.

  Sums duration of all tracks in the session and converts from milliseconds to minutes.
  """
  @spec total_duration(t()) :: integer()
  def total_duration(%__MODULE__{} = listening_session) do
    listening_session
    |> tracks()
    |> Enum.map(&(&1.duration_ms || 0))
    |> Enum.sum()
    |> div(60_000)
  end

  @doc """
  Checks if the given scope can view the retrospective for a session based on visibility settings.

  Returns `true` if:
  - The scope's user is an admin (can view all sessions)
  - Session is :public (anyone can view)
  - Session is :protected and scope has an authenticated user
  - Session is :private and scope's user is the session owner

  Returns `false` otherwise.
  """
  @spec can_view_retrospective?(t(), Scope.t()) :: boolean()
  def can_view_retrospective?(%__MODULE__{visibility: :public}, _scope), do: true

  def can_view_retrospective?(%__MODULE__{}, %Scope{user: %User{role: :admin}}), do: true

  def can_view_retrospective?(%__MODULE__{visibility: :protected}, %Scope{user: %User{}}), do: true

  def can_view_retrospective?(%__MODULE__{user_id: user_id, visibility: :private}, %Scope{
        user: %User{id: user_id}
      }),
      do: true

  def can_view_retrospective?(%__MODULE__{}, _scope), do: false

  defp has_active_session?(user_id, exclude_session_id) do
    from(s in __MODULE__,
      where: s.user_id == ^user_id and s.status == :active and s.id != ^exclude_session_id
    )
    |> Repo.exists?()
  end
end
