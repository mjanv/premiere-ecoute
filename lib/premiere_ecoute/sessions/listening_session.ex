defmodule PremiereEcoute.Sessions.ListeningSession do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.Discography.Track

  schema "listening_sessions" do
    field :status, Ecto.Enum, values: [:preparing, :active, :stopped], default: :preparing
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    belongs_to :user, User, foreign_key: :user_id
    belongs_to :album, Album, foreign_key: :album_id
    belongs_to :current_track, Track, foreign_key: :current_track_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(listening_session, attrs) do
    listening_session
    |> cast(attrs, [
      :album_id,
      :status,
      :started_at,
      :ended_at,
      :user_id,
      :current_track_id
    ])
    |> validate_required([:album_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:album_spotify_id)
    |> foreign_key_constraint(:current_track_id)
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:album_id, :user_id, :current_track_id])
    |> validate_required([:album_id, :user_id])
    |> put_change(:status, :preparing)
  end

  def preload(session) do
    Repo.preload(session, [album: [:tracks], user: [], current_track: []], force: true)
  end

  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, session} -> {:ok, preload(session)}
      {:error, reason} -> {:error, reason}
    end
  end

  def get(id) do
    __MODULE__
    |> Repo.get(id)
    |> preload()
  end

  def all do
    __MODULE__
    |> Repo.all()
    |> preload()
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
    |> Repo.update()
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
      {:ok, session} -> {:ok, preload(session)}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete(id) do
    __MODULE__
    |> Repo.get(id)
    |> case do
      nil ->
        :error

      session ->
        Repo.delete(session)
        :ok
    end
  end
end
