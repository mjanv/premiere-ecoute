defmodule PremiereEcoute.Sessions.ListeningSession do
  use Ecto.Schema
  import Ecto.Changeset

  alias PremiereEcoute.Music.{Album, Track}
  alias PremiereEcoute.Accounts.User

  schema "listening_sessions" do
    field :streamer_id, :string
    field :album_id, :string
    field :current_track_id, :string
    field :status, Ecto.Enum, values: [:preparing, :active, :stopped]
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    belongs_to :user, User, foreign_key: :user_id

    belongs_to :album, Album,
      foreign_key: :album_spotify_id,
      references: :spotify_id,
      type: :string

    belongs_to :current_track, Track,
      foreign_key: :current_track_spotify_id,
      references: :spotify_id,
      type: :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(listening_session, attrs) do
    listening_session
    |> cast(attrs, [
      :streamer_id,
      :album_id,
      :current_track_id,
      :status,
      :started_at,
      :ended_at,
      :user_id
    ])
    |> validate_required([:streamer_id, :album_id, :status])
    |> validate_inclusion(:status, [:preparing, :active, :stopped])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:album_spotify_id)
    |> foreign_key_constraint(:current_track_spotify_id)
  end

  @doc """
  Create a new listening session
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:streamer_id, :album_id, :current_track_id, :user_id])
    |> validate_required([:streamer_id, :album_id])
    |> put_change(:status, :preparing)
    |> put_change(:started_at, DateTime.utc_now())
  end

  @doc """
  Start an active session
  """
  def start_changeset(listening_session) do
    listening_session
    |> change()
    |> put_change(:status, :active)
    |> put_change(:started_at, DateTime.utc_now())
  end

  @doc """
  Stop a session
  """
  def stop_changeset(listening_session) do
    listening_session
    |> change()
    |> put_change(:status, :stopped)
    |> put_change(:ended_at, DateTime.utc_now())
  end
end
