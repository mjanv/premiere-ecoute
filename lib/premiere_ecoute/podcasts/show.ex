defmodule PremiereEcoute.Podcasts.Show do
  @moduledoc """
  Podcast show aggregate.

  A show is owned by a streamer and groups episodes. Each show is exposed as a single,
  public RSS feed (one feed per show) discoverable by podcast apps. The `slug` provides a
  stable, URL-friendly identifier used in the feed URL; it must be unique per owner.
  """

  use PremiereEcouteCore.Aggregate,
    root: [:user],
    identity: [:user_id, :slug],
    json: [:id, :slug, :title, :description, :author, :language, :category, :explicit, :cover_url, :published]

  defmodule Slug do
    @moduledoc false

    use EctoAutoslugField.Slug, from: :title, to: :slug
  end

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Events.ShowCreated
  alias PremiereEcoute.Events.ShowPublished
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Podcasts.Show.Slug

  # Apple Podcasts top-level categories. Kept as a constrained list so feeds validate.
  @categories ~w(Arts Business Comedy Education Fiction Government History
                 Health Kids Leisure Music News Religion Science Society
                 Sports Technology True\ Crime TV)

  @type t :: %__MODULE__{
          id: integer() | nil,
          slug: String.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          author: String.t() | nil,
          language: String.t() | nil,
          category: String.t() | nil,
          explicit: boolean(),
          cover_url: String.t() | nil,
          published: boolean(),
          user: entity(User.t()),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "podcasts_shows" do
    field :slug, Slug.Type
    field :title, :string
    field :description, :string
    field :author, :string
    field :language, :string, default: "en"
    field :category, :string
    field :explicit, :boolean, default: false
    field :cover_url, :string
    field :published, :boolean, default: false

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  defimpl String.Chars do
    def to_string(%{title: title}), do: title || ""
  end

  @doc "Returns the list of valid Apple Podcasts categories."
  @spec categories() :: [String.t()]
  def categories, do: @categories

  @doc "Creates changeset for a podcast show."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(show, attrs) do
    show
    |> cast(attrs, [:title, :description, :author, :language, :category, :explicit, :cover_url, :published, :user_id])
    |> update_change(:category, fn cat -> if cat in [nil, ""], do: nil, else: cat end)
    |> validate_required([:title, :user_id, :language])
    |> validate_inclusion(:category, @categories, message: "is not a valid Apple Podcasts category")
    |> Slug.maybe_generate_slug()
    |> unique_constraint([:user_id, :slug])
    |> foreign_key_constraint(:user_id)
  end

  @doc "Lists all shows owned by a user, most recently updated first."
  @spec all_for_user(User.t()) :: [t()]
  def all_for_user(%User{id: user_id}), do: all(where: [user_id: user_id], order_by: [desc: :updated_at])

  @doc "Fetches a published show by owner username and slug, or nil."
  @spec get_published(String.t(), String.t()) :: t() | nil
  def get_published(username, slug) do
    case PremiereEcoute.Accounts.get_user_by_username(username) do
      nil -> nil
      %User{id: user_id} -> get_by(user_id: user_id, slug: slug, published: true)
    end
  end

  @doc "Creates a show and emits a ShowCreated event."
  @spec create(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    attrs
    |> super()
    |> Store.ok("podcasts_show", fn show -> %ShowCreated{id: show.id, user_id: show.user_id} end)
  end

  @doc "Marks a show as published and emits a ShowPublished event."
  @spec publish(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def publish(%__MODULE__{} = show) do
    show
    |> update(%{published: true})
    |> Store.ok("podcasts_show", fn show -> %ShowPublished{id: show.id} end)
  end
end
