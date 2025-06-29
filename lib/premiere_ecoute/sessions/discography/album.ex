defmodule PremiereEcoute.Sessions.Discography.Album do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.Discography.Track

  schema "albums" do
    field :spotify_id, :string
    field :name, :string
    field :artist, :string
    field :release_date, :date
    field :cover_url, :string
    field :total_tracks, :integer

    has_many :tracks, Track, foreign_key: :album_id, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(album, attrs) do
    album
    |> cast(attrs, [:spotify_id, :name, :artist, :release_date, :cover_url, :total_tracks])
    |> validate_required([:spotify_id, :name, :artist, :total_tracks])
    |> validate_number(:total_tracks, greater_than: 0)
    |> unique_constraint(:spotify_id)
    |> cast_assoc(:tracks, with: &Track.changeset/2, required: true)
  end

  def create(%__MODULE__{} = album) do
    album
    |> Map.from_struct()
    |> Map.update!(:tracks, fn tracks -> Enum.map(tracks, &Map.from_struct/1) end)
    |> then(fn attrs -> Repo.insert(changeset(%__MODULE__{}, attrs)) end)
  end

  def get_or_create(%__MODULE__{spotify_id: spotify_id} = album) do
    case read(spotify_id) do
      %__MODULE__{} = album -> {:ok, album}
      nil -> create(album)
    end
  end

  def read(spotify_id) do
    __MODULE__
    |> Repo.get_by(spotify_id: spotify_id)
    |> Repo.preload([:tracks])
  end

  def delete(spotify_id) do
    case read(spotify_id) do
      nil ->
        :ok

      album ->
        case Repo.delete(album) do
          {:ok, _} -> :ok
          {:error, _} -> :error
        end
    end
  end
end
