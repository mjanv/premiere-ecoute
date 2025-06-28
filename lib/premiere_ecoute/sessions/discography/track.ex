defmodule PremiereEcoute.Sessions.Discography.Track do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias PremiereEcoute.Discography.Album

  schema "tracks" do
    field :spotify_id, :string
    field :name, :string
    field :track_number, :integer
    field :duration_ms, :integer

    belongs_to :album, Album

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(track, attrs) do
    track
    |> cast(attrs, [:spotify_id, :name, :track_number, :duration_ms, :album_id])
    |> validate_required([:spotify_id, :name, :track_number])
    |> validate_number(:track_number, greater_than: 0)
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:album_id)
    |> unique_constraint([:spotify_id, :album_id])
  end
end
