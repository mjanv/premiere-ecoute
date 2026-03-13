defmodule PremiereEcoute.Discography.Album do
  @moduledoc """
  Music album in the discography system.

  An album is a collection of tracks from a provider catalog that can be used
  in listening sessions. Albums are identified by their provider ID and contain
  metadata such as name, artist, release date, and cover art.
  """

  use PremiereEcouteCore.Aggregate,
    root: [:tracks, :artists],
    identity: [:provider, :album_id],
    json: [:id, :name, :slug, :artist, :release_date, :cover_url, :total_tracks, :tracks]

  defmodule Slug do
    @moduledoc false

    use EctoAutoslugField.Slug, from: :name, to: :slug, always_change: true
  end

  alias PremiereEcoute.Discography.Album.Slug
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.AlbumArtist
  alias PremiereEcoute.Discography.Artist
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
          tracks: entity([Track.t()]),
          artists: entity([Artist.t()]),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "albums" do
    field :provider, Ecto.Enum, values: [:spotify, :deezer]
    field :album_id, :string
    field :name, :string
    field :slug, Slug.Type
    field :release_date, :date
    field :cover_url, :string
    field :total_tracks, :integer
    field :artist, :string, virtual: true

    has_many :tracks, Track, foreign_key: :album_id, on_delete: :delete_all
    many_to_many :artists, Artist, join_through: AlbumArtist, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates changeset for album validation.

  Validates required fields, track count, provider type, and uniqueness constraints. Casts associated tracks.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(album, attrs) do
    album
    |> cast(attrs, [:provider, :album_id, :name, :release_date, :cover_url, :total_tracks])
    |> validate_required([:provider, :album_id, :name, :total_tracks])
    |> validate_number(:total_tracks, greater_than: 0)
    |> validate_inclusion(:provider, [:twitch, :spotify])
    |> unique_constraint([:album_id, :provider])
    |> foreign_key_constraint(:listening_sessions,
      name: :listening_sessions_album_id_fkey,
      message: "are still linked to this album"
    )
    |> cast_assoc(:tracks, with: &Track.changeset/2, required: true)
    |> Slug.maybe_generate_slug()
  end

  @doc """
  Populates the virtual :artist field from the first entry in :artists.
  """
  @spec put_artist(nil | t()) :: nil | t()
  def put_artist(nil), do: nil
  def put_artist(%__MODULE__{artists: [artist | _]} = album), do: %{album | artist: artist}
  def put_artist(%__MODULE__{} = album), do: album

  @doc false
  def preload({:ok, entity}), do: {:ok, preload(entity)}
  def preload({:error, reason}), do: {:error, reason}

  def preload(entities) when is_list(entities) do
    entities
    |> Repo.preload([:tracks, :artists], force: true)
    |> Enum.map(&put_artist/1)
  end

  def preload(entity) do
    entity
    |> Repo.preload([:tracks, :artists], force: true)
    |> put_artist()
  end

  @doc """
  Inserts album with tracks and artists into database.

  Overrides default create to handle track and artist association conversion before insertion.
  Artists are find-or-created by name before being linked via put_assoc.
  """
  @spec create(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(%__MODULE__{artists: artists} = album) do
    # AIDEV-NOTE: persist unpersisted Artist structs before put_assoc to avoid unique constraint errors
    artist_list = if is_list(artists), do: artists, else: []

    persisted_artists =
      Enum.map(artist_list, fn
        %Artist{id: nil} = a -> elem(Artist.create_if_not_exists(Map.from_struct(a)), 1)
        %Artist{} = a -> a
      end)

    album
    |> Map.from_struct()
    |> Map.update!(:tracks, fn tracks -> Enum.map(tracks, &Map.from_struct/1) end)
    |> then(fn attrs ->
      %__MODULE__{}
      |> changeset(attrs)
      |> put_assoc(:artists, persisted_artists)
      |> Repo.insert()
    end)
    |> preload()
  end

  @spec create_if_not_exists(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create_if_not_exists(%__MODULE__{} = album) do
    case get_by(Map.take(Map.from_struct(album), [:provider, :album_id])) do
      nil -> create(album)
      existing -> {:ok, existing}
    end
  end

  def get_by(query \\ __MODULE__, clauses), do: query |> Repo.get_by(clauses) |> preload()

  @spec get(integer()) :: t() | nil
  def get(id), do: __MODULE__ |> Repo.get(id) |> preload()

  def get_album_by_slug(slug), do: __MODULE__ |> Repo.get_by(slug: slug) |> preload()

  defimpl Jason.Encoder do
    def encode(album, opts) do
      album
      |> Map.take([:id, :name, :slug, :release_date, :cover_url, :total_tracks, :tracks])
      |> Map.put(:artist, if(album.artist, do: to_string(album.artist), else: nil))
      |> Jason.Encode.map(opts)
    end
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
