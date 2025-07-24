defmodule PremiereEcoute.Sessions.Discography.Track do
  @moduledoc """
  # Track Schema

  Schema representing individual music tracks within albums, storing track metadata from Spotify including name, track number, duration, and unique identifiers. Tracks belong to albums and serve as the fundamental unit for music playback and rating within listening sessions.
  """

  use PremiereEcoute.Core.Schema,
    json: [:id, :name, :track_number]

  alias PremiereEcoute.Sessions.Discography.Album

  @type t :: %__MODULE__{
          id: integer() | nil,
          spotify_id: String.t() | nil,
          name: String.t() | nil,
          track_number: integer() | nil,
          duration_ms: integer() | nil,
          album_id: integer() | nil,
          album: entity(Album.t()),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

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
    |> cast(attrs, [:spotify_id, :name, :track_number, :duration_ms])
    |> validate_required([:spotify_id, :name, :track_number])
    |> validate_number(:track_number, greater_than: 0)
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
    |> unique_constraint([:spotify_id])
  end
end
