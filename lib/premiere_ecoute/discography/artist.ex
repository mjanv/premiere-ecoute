defmodule PremiereEcoute.Discography.Artist do
  @moduledoc """
  Music artist in the discography system.

  An artist is a musician or band associated with albums. Artists are identified
  by their name and have a slug for URL-friendly references.
  """

  use PremiereEcouteCore.Aggregate,
    identity: [:name],
    json: [:id, :provider_ids, :name, :slug]

  defmodule Slug do
    @moduledoc false

    use EctoAutoslugField.Slug, from: :name, to: :slug, always_change: true
  end

  alias PremiereEcoute.Discography.Artist.Slug

  defmodule Image do
    @moduledoc false

    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :url, :string
      field :height, :integer
      field :width, :integer
    end

    def changeset(image, attrs) do
      cast(image, attrs, [:url, :height, :width])
    end
  end

  @type t :: %__MODULE__{
          id: integer() | nil,
          provider_ids: %{atom() => String.t()},
          name: String.t() | nil,
          slug: String.t() | nil,
          images: [Image.t()],
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "artists" do
    field :provider_ids, PremiereEcouteCore.Ecto.Map, default: %{}
    field :name, :string
    field :slug, Slug.Type

    embeds_many :images, Image, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  defimpl String.Chars do
    def to_string(%{name: name}), do: name || ""
  end

  defimpl Phoenix.HTML.Safe do
    def to_iodata(%{name: name}), do: name || ""
  end

  @spec create(t() | map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(%__MODULE__{} = artist) do
    artist
    |> Map.from_struct()
    |> Map.update(:images, [], fn images -> Enum.map(images, &Map.from_struct/1) end)
    |> then(fn attrs -> %__MODULE__{} |> changeset(attrs) |> Repo.insert() end)
  end

  @spec get_by_slug(String.t()) :: t() | nil
  def get_by_slug(slug), do: get_by(slug: slug)

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(artist, attrs) do
    artist
    |> cast(attrs, [:provider_ids, :name])
    |> validate_required([:name])
    |> unique_constraint(:name)
    |> cast_embed(:images)
    |> Slug.maybe_generate_slug()
  end
end
