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
          provider_ids: %{optional(atom()) => String.t()},
          external_links: %{optional(String.t()) => String.t()},
          name: String.t() | nil,
          slug: String.t() | nil,
          images: [Image.t()],
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "artists" do
    field :provider_ids, PremiereEcouteCore.Ecto.Map, default: %{}
    field :external_links, :map, default: %{}
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

  def create(attrs) when is_map(attrs) do
    %__MODULE__{} |> changeset(attrs) |> Repo.insert()
  end

  @doc "Returns the image URL closest to the given size, or nil if no images."
  @spec image_url(t(), non_neg_integer()) :: String.t() | nil
  def image_url(%__MODULE__{images: []}, _size), do: nil

  def image_url(%__MODULE__{images: images}, size) do
    %Image{url: url} = Enum.min_by(images, fn img -> abs((img.height || 0) - size) end)
    url
  end

  @spec get_by_slug(String.t()) :: t() | nil
  def get_by_slug(slug), do: get_by(slug: slug)

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

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(artist, attrs) do
    artist
    |> cast(attrs, [:provider_ids, :external_links, :name])
    |> validate_required([:name])
    |> validate_external_links()
    |> unique_constraint(:name)
    |> cast_embed(:images)
    |> Slug.maybe_generate_slug()
  end
end
