defmodule PremiereEcoute.Music.Track do
  use Ecto.Schema
  import Ecto.Changeset

  alias PremiereEcoute.Music.Album

  schema "tracks" do
    field :spotify_id, :string
    field :name, :string
    field :track_number, :integer
    field :duration_ms, :integer
    field :preview_url, :string

    belongs_to :album, Album

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(track, attrs) do
    track
    |> cast(attrs, [:spotify_id, :name, :track_number, :duration_ms, :preview_url, :album_id])
    |> validate_required([:spotify_id, :name, :track_number, :album_id])
    |> validate_length(:spotify_id, max: 255)
    |> validate_length(:name, max: 500)
    |> validate_length(:preview_url, max: 1000)
    |> validate_number(:track_number, greater_than: 0)
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:album_id)
    |> unique_constraint([:spotify_id, :album_id])
  end
end
