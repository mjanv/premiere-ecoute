defmodule PremiereEcoute.Discography.Album do
  @moduledoc """
  Music album in the discography system.

  An album is a collection of tracks from a provider catalog that can be used
  in listening sessions. Albums are identified by their provider ID and contain
  metadata such as name, artist, release date, and cover art.
  """

  use PremiereEcouteCore.Aggregate,
    root: [:tracks, :artists],
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
          provider_ids: %{atom() => String.t()},
          external_links: %{optional(String.t()) => String.t()},
          name: String.t() | nil,
          artist: Artist.t() | String.t() | nil,
          release_date: Date.t() | nil,
          cover_url: String.t() | nil,
          total_tracks: integer() | nil,
          tracks: entity([Track.t()]),
          artists: entity([Artist.t()]),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "albums" do
    field :provider_ids, PremiereEcouteCore.Ecto.Map, default: %{}
    field :external_links, :map, default: %{}
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
    |> cast(attrs, [:provider_ids, :external_links, :name, :release_date, :cover_url, :total_tracks])
    |> validate_required([:provider_ids, :name, :total_tracks])
    |> validate_external_links()
    |> validate_number(:total_tracks, greater_than: 0)
    |> foreign_key_constraint(:listening_sessions,
      name: :listening_sessions_album_id_fkey,
      message: "are still linked to this album"
    )
    |> cast_assoc(:tracks, with: &Track.changeset/2, required: true)
    |> Slug.maybe_generate_slug()
    |> unique_constraint(:provider_ids, name: :albums_spotify_id_unique)
    |> unique_constraint(:provider_ids, name: :albums_deezer_id_unique)
  end

  @doc """
  Populates the virtual :artist field from the first entry in :artists.
  """
  @spec put_artist(nil | t()) :: nil | t()
  # AIDEV-NOTE: intentionally parallel to Single.put_artist/1 — both derive :artist from :artists
  def put_artist(nil), do: nil
  def put_artist(%__MODULE__{artists: [artist | _]} = album), do: %{album | artist: artist}
  def put_artist(%__MODULE__{} = album), do: album

  @doc false
  def preload({:ok, entity}), do: {:ok, preload(entity)}
  def preload({:error, reason}), do: {:error, reason}
  def preload(nil), do: nil
  def preload(entities) when is_list(entities), do: Enum.map(entities, &preload/1)

  def preload(%__MODULE__{} = album) do
    album
    |> super()
    |> put_artist()
  end

  @doc """
  Inserts album with tracks and artists into database.

  Overrides default create to handle track and artist association conversion before insertion.
  Artists are find-or-created by name before being linked via put_assoc.
  """
  @spec create(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(%__MODULE__{artists: artists} = album) do
    artists = if is_list(artists), do: artists, else: []

    artists =
      Enum.map(artists, fn
        %Artist{id: nil} = a -> elem(Artist.create_if_not_exists(Map.from_struct(a)), 1)
        %Artist{} = a -> a
      end)

    album
    |> Map.from_struct()
    |> Map.update!(:tracks, fn tracks -> Enum.map(tracks, &Map.from_struct/1) end)
    |> then(fn attrs ->
      %__MODULE__{}
      |> changeset(attrs)
      |> put_assoc(:artists, artists)
      |> Repo.insert()
    end)
    |> preload()
  end

  @spec create_if_not_exists(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create_if_not_exists(%__MODULE__{provider_ids: provider_ids} = album) when map_size(provider_ids) > 0 do
    [{provider, id}] = Enum.take(provider_ids, 1)

    from(a in __MODULE__,
      where: fragment("?->>? = ?", a.provider_ids, ^to_string(provider), ^id)
    )
    |> Repo.one()
    |> preload()
    |> case do
      nil -> create(album)
      album -> {:ok, album}
    end
  end

  def create_if_not_exists(%__MODULE__{} = album), do: create(album)

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

  defp validate_external_links(%Ecto.Changeset{} = changeset) do
    case get_change(changeset, :external_links) do
      nil -> changeset
      links -> Enum.reduce(links, changeset, &validate_link/2)
    end
  end

  defp validate_link({_key, nil}, changeset), do: changeset

  defp validate_link({_key, url}, changeset) do
    if url =~ ~r/\Ahttps?:\/\/.+/i do
      changeset
    else
      add_error(changeset, :external_links, "contains invalid URL: #{url}")
    end
  end

  @doc "Returns a random album with missing informations"
  @spec random :: nil | t()
  def random do
    from(a in __MODULE__,
      where:
        fragment("? \\? 'wikipedia' = false", a.external_links) or
          fragment("NOT (? \\? 'deezer')", a.provider_ids) or
          fragment("NOT (? \\? 'spotify')", a.provider_ids) or
          fragment("NOT (? \\? 'tidal')", a.provider_ids)
    )
    |> order_by(fragment("RANDOM()"))
    |> limit(1)
    |> Repo.one()
    |> preload()
  end
end
