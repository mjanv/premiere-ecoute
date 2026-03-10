defmodule PremiereEcoute.Collections.CollectionSession do
  @moduledoc """
  Collection session aggregate.

  Manages a live curation session where tracks from an origin playlist are played and decided
  upon (kept, rejected, or skipped). Decided tracks are synced to the destination playlist
  upon completion.
  """

  use PremiereEcouteCore.Aggregate,
    root: [
      user: [:twitch, :spotify],
      origin_playlist: [],
      destination_playlist: [],
      decisions: []
    ],
    json: [:id, :status, :rule, :selection_mode, :current_index]

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Collections.CollectionDecision
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Repo

  @type t :: %__MODULE__{
          id: integer() | nil,
          status: :pending | :active | :completed,
          rule: :ordered | :random,
          selection_mode: :streamer_choice | :viewer_vote | :duel,
          vote_duration: integer() | nil,
          current_index: integer(),
          user: entity(User.t()),
          origin_playlist: entity(LibraryPlaylist.t()),
          destination_playlist: entity(LibraryPlaylist.t()),
          decisions: [CollectionDecision.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "collection_sessions" do
    field :status, Ecto.Enum, values: [:pending, :active, :completed], default: :pending
    field :rule, Ecto.Enum, values: [:ordered, :random], default: :ordered
    field :selection_mode, Ecto.Enum, values: [:streamer_choice, :viewer_vote, :duel], default: :streamer_choice
    field :vote_duration, :integer
    field :current_index, :integer, default: 0

    belongs_to :user, User
    belongs_to :origin_playlist, LibraryPlaylist
    belongs_to :destination_playlist, LibraryPlaylist

    has_many :decisions, CollectionDecision, foreign_key: :collection_session_id

    timestamps(type: :utc_datetime)
  end

  @doc "Creates changeset for collection session."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :status,
      :rule,
      :selection_mode,
      :vote_duration,
      :current_index,
      :user_id,
      :origin_playlist_id,
      :destination_playlist_id
    ])
    |> validate_required([:rule, :selection_mode, :user_id, :origin_playlist_id, :destination_playlist_id])
    |> validate_inclusion(:status, [:pending, :active, :completed])
    |> validate_inclusion(:rule, [:ordered, :random])
    |> validate_inclusion(:selection_mode, [:streamer_choice, :viewer_vote, :duel])
    |> validate_vote_duration()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:origin_playlist_id)
    |> foreign_key_constraint(:destination_playlist_id)
  end

  @doc "Transitions session from pending to active."
  @spec start(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def start(%__MODULE__{} = session) do
    session
    |> changeset(%{status: :active})
    |> Repo.update()
  end

  @doc "Transitions session from active to completed."
  @spec complete(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def complete(%__MODULE__{} = session) do
    session
    |> changeset(%{status: :completed})
    |> Repo.update()
  end

  @doc "Advances current_index by the given step (1 for normal, 2 for duel)."
  @spec advance(t(), integer()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def advance(%__MODULE__{} = session, step \\ 1) do
    session
    |> changeset(%{current_index: session.current_index + step})
    |> Repo.update()
  end

  @doc "Returns all sessions for a user, ordered by most recent."
  @spec all_for_user(User.t()) :: [t()]
  def all_for_user(%User{id: user_id}) do
    from(s in __MODULE__,
      where: s.user_id == ^user_id,
      order_by: [desc: s.inserted_at],
      preload: [:origin_playlist, :destination_playlist]
    )
    |> Repo.all()
  end

  defp validate_vote_duration(changeset) do
    case get_field(changeset, :selection_mode) do
      mode when mode in [:viewer_vote, :duel] ->
        validate_required(changeset, [:vote_duration])

      _ ->
        changeset
    end
  end
end
