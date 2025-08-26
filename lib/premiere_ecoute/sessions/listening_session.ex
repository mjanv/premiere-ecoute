defmodule PremiereEcoute.Sessions.ListeningSession do
  @moduledoc false

  use PremiereEcouteCore.Aggregate,
    root: [album: [:tracks], user: [:twitch, :spotify], current_track: []],
    json: [:id, :status, :started_at, :ended_at, :user, :album, :current_track]

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Follow
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcouteCore.Cache

  @type t :: %__MODULE__{
          id: integer() | nil,
          status: atom(),
          started_at: DateTime.t() | nil,
          ended_at: DateTime.t() | nil,
          user: entity(User.t()),
          album: entity(Album.t()),
          current_track: entity(Album.Track.t()),
          report: entity(Report.t()),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "listening_sessions" do
    field :status, Ecto.Enum, values: [:preparing, :active, :stopped], default: :preparing
    field :vote_options, {:array, :string}, default: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    belongs_to :user, User, foreign_key: :user_id

    belongs_to :album, Album, foreign_key: :album_id
    belongs_to :current_track, Album.Track, foreign_key: :current_track_id

    has_one :report, Report, foreign_key: :session_id

    timestamps(type: :utc_datetime)
  end

  def changeset(listening_session, attrs) do
    listening_session
    |> cast(attrs, [
      :album_id,
      :status,
      :vote_options,
      :started_at,
      :ended_at,
      :user_id,
      :current_track_id
    ])
    |> validate_required([:album_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:album_id)
    |> foreign_key_constraint(:current_track_id)
  end

  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, session} ->
        session = preload(session)

        if session.user && session.user.twitch do
          Cache.put(:sessions, session.user.twitch.user_id, {session.id, session.vote_options, nil})
        end

        {:ok, session}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def start(%__MODULE__{} = session) do
    session
    |> change()
    |> put_change(:status, :active)
    |> put_change(:started_at, DateTime.utc_now(:second))
    |> Repo.update()
  end

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

  def next_track(%__MODULE__{} = session) do
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

  def previous_track(%__MODULE__{} = session) do
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

  def current_track(%__MODULE__{} = session, track_id) do
    session
    |> change()
    |> put_change(:current_track_id, track_id)
    |> Repo.update()
    |> case do
      {:ok, session} ->
        session = preload(session)

        if session.user && session.user.twitch do
          Cache.put(:sessions, session.user.twitch.user_id, {session.id, session.vote_options, track_id})
        end

        {:ok, session}

      {:error, reason} ->
        {:error, reason}
    end
  end

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
end
