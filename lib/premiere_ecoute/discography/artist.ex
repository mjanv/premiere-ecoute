defmodule PremiereEcoute.Discography.Artist do
  @moduledoc """
  Music artist in the discography system.

  An artist is a musician or band associated with albums. Artists are identified
  by their name and have a slug for URL-friendly references.
  """

  use PremiereEcouteCore.Aggregate,
    identity: [:name],
    json: [:id, :name, :slug]

  defmodule Slug do
    @moduledoc false

    use EctoAutoslugField.Slug, from: :name, to: :slug, always_change: true
  end

  alias PremiereEcoute.Discography.Artist.Slug

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          slug: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "artists" do
    field :name, :string
    field :slug, Slug.Type

    timestamps(type: :utc_datetime)
  end

  defimpl String.Chars do
    def to_string(%{name: name}), do: name || ""
  end

  defimpl Phoenix.HTML.Safe do
    def to_iodata(%{name: name}), do: name || ""
  end

  @spec get_by_slug(String.t()) :: t() | nil
  def get_by_slug(slug), do: get_by(slug: slug)

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(artist, attrs) do
    artist
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
    |> Slug.maybe_generate_slug()
  end
end
