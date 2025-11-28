defmodule PremiereEcoute.Discography.Album.Track do
  @moduledoc """
  Album Track

  Schema representing individual music tracks within albums, storing track metadata from Spotify including name, track number, duration, and unique identifiers. Tracks belong to albums and serve as the fundamental unit for music playback and rating within listening sessions.
  """

  use PremiereEcouteCore.Aggregate,
    json: [:id, :name, :track_number]

  alias PremiereEcoute.Discography.Album

  @type t :: %__MODULE__{
          id: integer() | nil,
          track_id: String.t() | nil,
          name: String.t() | nil,
          track_number: integer() | nil,
          duration_ms: integer() | nil,
          album_id: integer() | nil,
          album: entity(Album.t()),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "album_tracks" do
    field :provider, Ecto.Enum, values: [:spotify, :deezer]
    field :track_id, :string
    field :name, :string
    field :track_number, :integer
    field :duration_ms, :integer

    belongs_to :album, Album

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates changeset for track validation.

  Validates required fields, track number, duration, and provider type. Ensures uniqueness of track ID per provider.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(track, attrs) do
    track
    |> cast(attrs, [:provider, :track_id, :name, :track_number, :duration_ms])
    |> validate_required([:provider, :track_id, :name, :track_number])
    |> validate_number(:track_number, greater_than: 0)
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
    |> validate_inclusion(:provider, [:twitch, :spotify])
    |> unique_constraint([:track_id, :provider])
  end
end
