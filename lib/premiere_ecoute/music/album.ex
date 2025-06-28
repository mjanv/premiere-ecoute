defmodule PremiereEcoute.Music.Album do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias PremiereEcoute.Music.Track

  schema "albums" do
    field :spotify_id, :string
    field :name, :string
    field :artist, :string
    field :release_date, :date
    field :cover_url, :string
    field :total_tracks, :integer

    has_many :tracks, Track, foreign_key: :album_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(album, attrs) do
    album
    |> cast(attrs, [:spotify_id, :name, :artist, :release_date, :cover_url, :total_tracks])
    |> validate_required([:spotify_id, :name, :artist, :total_tracks])
    |> validate_length(:spotify_id, max: 255)
    |> validate_length(:name, max: 500)
    |> validate_length(:artist, max: 255)
    |> validate_length(:cover_url, max: 1000)
    |> validate_number(:total_tracks, greater_than: 0)
    |> unique_constraint(:spotify_id)
  end

  @doc """
  Create changeset from Spotify API data
  """
  def from_spotify_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:spotify_id, :name, :artist, :release_date, :cover_url, :total_tracks])
    |> validate_required([:spotify_id, :name, :artist, :total_tracks])
    |> unique_constraint(:spotify_id)
  end
end
