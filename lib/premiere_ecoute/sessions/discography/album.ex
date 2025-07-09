defmodule PremiereEcoute.Sessions.Discography.Album do
  @moduledoc false

  use PremiereEcoute.Core.Schema,
    root: [:tracks],
    identity: [:spotify_id]

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.Discography.Track

  @type t :: %__MODULE__{
          id: integer() | nil,
          spotify_id: String.t() | nil,
          name: String.t() | nil,
          artist: String.t() | nil,
          release_date: Date.t() | nil,
          cover_url: String.t() | nil,
          total_tracks: integer() | nil,
          tracks: [Track.t()],
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

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

  def delete(album) do
    album
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.foreign_key_constraint(:album_id, name: "listening_sessions_album_id_fkey")
    |> Repo.delete(allow_stale: true)
  end
end
