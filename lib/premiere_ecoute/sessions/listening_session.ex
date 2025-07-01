defmodule PremiereEcoute.Sessions.ListeningSession do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.Discography.Album

  schema "listening_sessions" do
    field :status, Ecto.Enum, values: [:preparing, :active, :stopped], default: :preparing
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    belongs_to :user, User, foreign_key: :user_id
    belongs_to :album, Album, foreign_key: :album_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(listening_session, attrs) do
    listening_session
    |> cast(attrs, [
      # :streamer_id,
      :album_id,
      :status,
      :started_at,
      :ended_at,
      :user_id
    ])
    |> validate_required([:album_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:album_spotify_id)
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:album_id, :user_id])
    |> validate_required([:album_id, :user_id])
    |> put_change(:status, :preparing)
  end

  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, session} -> {:ok, Repo.preload(session, [album: [:tracks], user: []])}
      {:error, reason} -> {:error, reason}
    end
  end

  def get(id) do
    __MODULE__
    |> Repo.get(id)
    |> Repo.preload([album: [:tracks], user: []])
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


  def delete(id) do
    __MODULE__
    |> Repo.get(id)
    |> case do
      nil -> :error
      session ->
        Repo.delete(session)
        :ok
    end
  end
end
