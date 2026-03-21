defmodule PremiereEcoute.Discography.Album.Track do
  @moduledoc """
  Album Track

  Schema representing individual music tracks within albums, storing track metadata from Spotify including name, track number, duration, and unique identifiers. Tracks belong to albums and serve as the fundamental unit for music playback and rating within listening sessions.
  """

  use PremiereEcouteCore.Aggregate,
    json: [:id, :name, :track_number]

  defmodule Slug do
    @moduledoc false

    use EctoAutoslugField.Slug, from: :name, to: :slug, always_change: true
  end

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track.Slug

  @type t :: %__MODULE__{
          id: integer() | nil,
          provider_ids: %{atom() => String.t()},
          external_links: %{optional(String.t()) => String.t()},
          name: String.t() | nil,
          track_number: integer() | nil,
          duration_ms: integer() | nil,
          album_id: integer() | nil,
          album: entity(Album.t()),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "album_tracks" do
    field :provider_ids, PremiereEcouteCore.Ecto.Map, default: %{}
    field :external_links, :map, default: %{}
    field :name, :string
    field :slug, Slug.Type
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
    |> cast(attrs, [:provider_ids, :external_links, :name, :track_number, :duration_ms])
    |> validate_required([:provider_ids, :name, :track_number])
    |> validate_external_links()
    |> validate_number(:track_number, greater_than: 0)
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
    |> Slug.maybe_generate_slug()
    |> unique_constraint(:provider_ids, name: :album_tracks_spotify_id_unique)
    |> unique_constraint(:provider_ids, name: :album_tracks_deezer_id_unique)
  end

  def provider(%__MODULE__{provider_ids: providers_ids}, provider), do: Map.get(providers_ids, provider)

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
end
