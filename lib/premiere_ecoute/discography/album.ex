defmodule PremiereEcoute.Discography.Album do
  @moduledoc """
  Music album in the discography system.

  An album is a collection of tracks from a provider catalog that can be used
  in listening sessions. Albums are identified by their provider ID and contain
  metadata such as name, artist, release date, and cover art.
  """

  use PremiereEcouteCore.Aggregate,
    root: [:tracks],
    identity: [:provider, :album_id],
    json: [:id, :name, :artist, :release_date, :cover_url, :total_tracks, :tracks]

  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Repo

  @type t :: %__MODULE__{
          id: integer() | nil,
          provider: :spotify | :deezer,
          album_id: String.t() | nil,
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
    field :provider, Ecto.Enum, values: [:spotify, :deezer]
    field :album_id, :string
    field :name, :string
    field :artist, :string
    field :release_date, :date
    field :cover_url, :string
    field :total_tracks, :integer

    has_many :tracks, Track, foreign_key: :album_id, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates changeset for album validation.

  Validates required fields, track count, provider type, and uniqueness constraints. Casts associated tracks.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(album, attrs) do
    album
    |> cast(attrs, [:provider, :album_id, :name, :artist, :release_date, :cover_url, :total_tracks])
    |> validate_required([:provider, :album_id, :name, :artist, :total_tracks])
    |> validate_number(:total_tracks, greater_than: 0)
    |> validate_inclusion(:provider, [:twitch, :spotify])
    |> unique_constraint([:album_id, :provider])
    |> foreign_key_constraint(:listening_sessions,
      name: :listening_sessions_album_id_fkey,
      message: "are still linked to this album"
    )
    |> cast_assoc(:tracks, with: &Track.changeset/2, required: true)
  end

  @doc """
  Inserts album with tracks into database.

  Overrides default create to handle track association conversion before insertion.
  """
  @spec create(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(%__MODULE__{} = album) do
    album
    |> Map.from_struct()
    |> Map.update!(:tracks, fn tracks -> Enum.map(tracks, &Map.from_struct/1) end)
    |> then(fn attrs -> Repo.insert(changeset(%__MODULE__{}, attrs)) end)
  end

  @doc """
  Calculates total album duration in milliseconds.

  Sums duration of all tracks, treating nil durations as zero.
  """
  @spec total_duration(t()) :: integer()
  def total_duration(%__MODULE__{tracks: tracks}) do
    tracks
    |> Enum.map(&(&1.duration_ms || 0))
    |> Enum.sum()
  end
end
