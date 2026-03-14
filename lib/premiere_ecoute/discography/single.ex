defmodule PremiereEcoute.Discography.Single do
  @moduledoc """
  Single track in the discography system.

  A single is a standalone track (not tied to an album or playlist) that can be used
  in a lightweight listening session. Identified by provider and track ID.
  """

  use PremiereEcouteCore.Aggregate,
    root: [:artists],
    json: [:id, :name, :slug, :artist, :cover_url, :duration_ms]

  defmodule Slug do
    @moduledoc false
    use EctoAutoslugField.Slug, from: :name, to: :slug, always_change: true
  end

  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Single.Slug
  alias PremiereEcoute.Discography.SingleArtist
  alias PremiereEcoute.Repo

  @type t :: %__MODULE__{
          id: integer() | nil,
          provider_ids: %{atom() => String.t()},
          name: String.t() | nil,
          slug: String.t() | nil,
          artist: Artist.t() | nil,
          artists: entity([Artist.t()]),
          duration_ms: integer() | nil,
          cover_url: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "singles" do
    field :provider_ids, PremiereEcouteCore.Ecto.Map, default: %{}
    field :name, :string
    field :slug, Slug.Type
    field :duration_ms, :integer
    field :cover_url, :string
    field :artist, :any, virtual: true

    many_to_many :artists, Artist, join_through: SingleArtist, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc "Populates the virtual :artist field from the first entry in :artists."
  @spec put_artist(nil | t()) :: nil | t()
  def put_artist(nil), do: nil
  def put_artist(%__MODULE__{artists: [artist | _]} = single), do: %{single | artist: artist}
  def put_artist(%__MODULE__{} = single), do: single

  def preload({:ok, entity}), do: {:ok, preload(entity)}
  def preload({:error, reason}), do: {:error, reason}
  def preload(nil), do: nil
  def preload(entities) when is_list(entities), do: Enum.map(entities, &preload/1)

  def preload(%__MODULE__{} = single) do
    single
    |> super()
    |> put_artist()
  end

  def get_by(clauses), do: get_by(__MODULE__, clauses)

  def get_by(query, clauses) do
    query |> Repo.get_by(clauses) |> preload()
  end

  def get(id), do: __MODULE__ |> Repo.get(id) |> preload()

  def create(%__MODULE__{artists: artists} = single) do
    artist_list = if is_list(artists), do: artists, else: []

    persisted_artists =
      Enum.map(artist_list, fn
        %Artist{id: nil} = a -> elem(Artist.create_if_not_exists(Map.from_struct(a)), 1)
        %Artist{} = a -> a
      end)

    single
    |> Map.from_struct()
    |> then(fn attrs ->
      %__MODULE__{}
      |> changeset(attrs)
      |> put_assoc(:artists, persisted_artists)
      |> Repo.insert()
    end)
    |> preload()
  end

  def create_if_not_exists(%__MODULE__{provider_ids: provider_ids} = single) when map_size(provider_ids) > 0 do
    # AIDEV-NOTE: lookup by first provider entry since there is no unique constraint on provider_ids
    [{provider, id}] = Enum.take(provider_ids, 1)

    result =
      from(s in __MODULE__,
        where: fragment("?->>? = ?", s.provider_ids, ^to_string(provider), ^id)
      )
      |> Repo.one()
      |> preload()

    case result do
      nil -> create(single)
      existing -> {:ok, existing}
    end
  end

  def create_if_not_exists(%__MODULE__{} = single), do: create(single)

  @doc "Creates changeset for single validation."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(single, attrs) do
    single
    |> cast(attrs, [:provider_ids, :name, :duration_ms, :cover_url])
    |> validate_required([:provider_ids, :name])
    |> Slug.maybe_generate_slug()
    |> unique_constraint(:provider_ids, name: :singles_spotify_id_unique)
    |> unique_constraint(:provider_ids, name: :singles_deezer_id_unique)
  end

  @spec get_by_slug(String.t()) :: t() | nil
  def get_by_slug(slug), do: get_by(slug: slug)

  # AIDEV-NOTE: custom Jason encoder to serialize :artist as name string
  defimpl Jason.Encoder do
    def encode(single, opts) do
      single
      |> Map.take([:id, :name, :cover_url, :duration_ms])
      |> Map.put(:artist, if(single.artist, do: to_string(single.artist), else: nil))
      |> Jason.Encode.map(opts)
    end
  end
end
