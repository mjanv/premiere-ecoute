defmodule PremiereEcoute.Podcasts.Episode do
  @moduledoc """
  Podcast episode aggregate.

  An episode belongs to a show and points at an MP3 stored in object storage. The `guid` and
  `audio_key` are write-once: podcast apps treat a changed GUID or enclosure URL as a new (or
  duplicate) episode, so re-uploading audio must create a new episode rather than mutate these.

  Lifecycle: `:uploading` -> `:processing` -> `:ready` (-> published via `published_at`). `:failed`
  is terminal for a botched ingestion.
  """

  use PremiereEcouteCore.Aggregate,
    root: [show: [:user]],
    identity: [:guid],
    json: [:id, :guid, :title, :description, :duration_seconds, :audio_byte_size, :status, :published_at]

  alias PremiereEcoute.Events.EpisodePublished
  alias PremiereEcoute.Events.EpisodeUploaded
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Podcasts.Show

  @statuses [:uploading, :processing, :ready, :failed]
  @episode_types [:full, :trailer, :bonus]

  @type t :: %__MODULE__{
          id: integer() | nil,
          guid: String.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          audio_key: String.t() | nil,
          audio_byte_size: integer() | nil,
          duration_seconds: integer() | nil,
          season: integer() | nil,
          episode_number: integer() | nil,
          episode_type: :full | :trailer | :bonus,
          status: :uploading | :processing | :ready | :failed,
          published_at: DateTime.t() | nil,
          show: entity(Show.t()),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "podcasts_episodes" do
    field :guid, :string
    field :title, :string
    field :description, :string
    field :audio_key, :string
    field :audio_byte_size, :integer
    field :duration_seconds, :integer
    field :season, :integer
    field :episode_number, :integer
    field :episode_type, Ecto.Enum, values: @episode_types, default: :full
    field :status, Ecto.Enum, values: @statuses, default: :uploading
    field :published_at, :utc_datetime

    belongs_to :show, Show

    timestamps(type: :utc_datetime)
  end

  defimpl String.Chars do
    def to_string(%{title: title}), do: title || ""
  end

  @doc "Creates changeset for a podcast episode. Generates a permanent GUID when absent."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(episode, attrs) do
    episode
    |> cast(attrs, [
      :guid,
      :title,
      :description,
      :audio_key,
      :audio_byte_size,
      :duration_seconds,
      :season,
      :episode_number,
      :episode_type,
      :status,
      :published_at,
      :show_id
    ])
    |> maybe_put_guid()
    |> validate_required([:guid, :title, :show_id])
    |> validate_number(:audio_byte_size, greater_than: 0)
    |> validate_number(:duration_seconds, greater_than: 0)
    |> validate_number(:season, greater_than: 0)
    |> validate_number(:episode_number, greater_than: 0)
    |> unique_constraint(:guid)
    |> foreign_key_constraint(:show_id)
  end

  @doc "Returns the valid Apple episode types."
  @spec episode_types() :: [atom()]
  def episode_types, do: @episode_types

  defp maybe_put_guid(changeset) do
    case get_field(changeset, :guid) do
      nil -> put_change(changeset, :guid, Ecto.UUID.generate())
      _ -> changeset
    end
  end

  @doc "Lists episodes for a show, newest published first then drafts, for admin views."
  @spec all_for_show(Show.t()) :: [t()]
  def all_for_show(%Show{id: show_id}),
    do: all(where: [show_id: show_id], order_by: [desc_nulls_first: :published_at])

  @doc """
  Lists episodes that should appear in a show's public feed: ready and published at or before now,
  newest first. Capped (Apple recommends limiting very long feeds).
  """
  @spec feed_episodes(Show.t()) :: [t()]
  def feed_episodes(%Show{id: show_id}) do
    now = DateTime.utc_now()

    __MODULE__
    |> where([e], e.show_id == ^show_id and e.status == :ready and not is_nil(e.published_at) and e.published_at <= ^now)
    |> order_by([e], desc: e.published_at)
    |> limit(300)
    |> Repo.all()
  end

  @doc "Fetches a ready, published (published_at set and due) episode by GUID within a show, or nil."
  @spec get_published(integer(), String.t()) :: t() | nil
  def get_published(show_id, guid) do
    now = DateTime.utc_now()

    __MODULE__
    |> where(
      [e],
      e.show_id == ^show_id and e.guid == ^guid and e.status == :ready and
        not is_nil(e.published_at) and e.published_at <= ^now
    )
    |> Repo.one()
  end

  @doc "Creates an episode and emits an EpisodeUploaded event."
  @spec create(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    attrs
    |> super()
    |> Store.ok("podcasts_episode", fn episode -> %EpisodeUploaded{id: episode.id, show_id: episode.show_id} end)
  end

  @doc "Stores extracted metadata and marks the episode ready."
  @spec mark_ready(t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def mark_ready(%__MODULE__{} = episode, attrs) do
    update(episode, Map.merge(attrs, %{status: :ready}))
  end

  @doc "Marks the episode failed."
  @spec mark_failed(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def mark_failed(%__MODULE__{} = episode), do: update(episode, %{status: :failed})

  @doc "Publishes a ready episode into the feed (sets published_at) and emits EpisodePublished."
  @spec publish(t(), DateTime.t()) :: {:ok, t()} | {:error, Ecto.Changeset.t() | :not_ready}
  def publish(episode, at \\ DateTime.utc_now())

  def publish(%__MODULE__{status: :ready} = episode, at) do
    episode
    |> update(%{published_at: DateTime.truncate(at, :second)})
    |> Store.ok("podcasts_episode", fn e -> %EpisodePublished{id: e.id, show_id: e.show_id} end)
  end

  def publish(%__MODULE__{}, _at), do: {:error, :not_ready}
end
