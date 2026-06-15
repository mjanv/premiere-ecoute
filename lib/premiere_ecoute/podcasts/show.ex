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
    json: [:id, :slug, :title, :description, :author, :language, :category, :explicit, :published]

  defmodule Slug do
    @moduledoc false

    use EctoAutoslugField.Slug, from: :title, to: :slug
  end

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Events.PodcastShowPublished
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
          cover_key: String.t() | nil,
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
    field :cover_key, :string
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
    |> cast(attrs, [:title, :description, :author, :language, :category, :explicit, :cover_key, :published, :user_id])
    |> update_change(:category, fn cat -> if cat in [nil, ""], do: nil, else: cat end)
    |> validate_required([:title, :user_id, :language])
    |> validate_inclusion(:category, @categories, message: "is not a valid Apple Podcasts category")
    |> Slug.maybe_generate_slug()
    # Attach the per-user uniqueness error to :slug (the conflicting field) for clearer UX.
    |> unique_constraint(:slug, name: :podcasts_shows_user_id_slug_index)
    |> foreign_key_constraint(:user_id)
  end

  @doc "Lists all shows owned by a user, most recently updated first."
  @spec all_for_user(User.t()) :: [t()]
  def all_for_user(%User{id: user_id}), do: all(where: [user_id: user_id], order_by: [desc: :updated_at])

  @doc """
  Returns published shows owned by the given `user_ids`, grouped by `user_id`
  (`%{user_id => [show]}`). Used to list each followed streamer's podcasts on the home page.
  """
  @spec published_by_users([integer()]) :: %{optional(integer()) => [t()]}
  def published_by_users(user_ids) do
    __MODULE__
    |> where([s], s.user_id in ^user_ids and s.published == true)
    |> order_by([s], desc: s.updated_at)
    |> Repo.all()
    |> Enum.group_by(& &1.user_id)
  end

  @doc "Fetches a published show by owner username and slug, or nil."
  @spec get_published(String.t(), String.t()) :: t() | nil
  def get_published(username, slug) do
    case PremiereEcoute.Accounts.get_user_by_username(username) do
      nil -> nil
      %User{id: user_id} -> get_by(user_id: user_id, slug: slug, published: true)
    end
  end

  @doc "Marks a show as published and emits a PodcastShowPublished event."
  @spec publish(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def publish(%__MODULE__{} = show) do
    # AIDEV-NOTE: changeset + Repo.update, not the generated update/2 (Ecto.Query.update/2 shadows it).
    show
    |> changeset(%{published: true})
    |> Repo.update()
    |> preload()
    |> Store.ok("podcasts_show", fn show -> %PodcastShowPublished{id: show.id} end)
  end
end
