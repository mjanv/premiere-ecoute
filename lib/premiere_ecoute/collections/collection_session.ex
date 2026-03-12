defmodule PremiereEcoute.Collections.CollectionSession do
  @moduledoc """
  Collection session aggregate.

  Manages a live curation session where tracks from an origin playlist are played and decided
  upon (kept, rejected, or skipped). Decided tracks are synced to the destination playlist
  upon completion.

  Decisions are stored as three arrays of track_ids directly on the session.
  """

  use PremiereEcouteCore.Aggregate,
    root: [
      user: [:twitch, :spotify],
      origin_playlist: [],
      destination_playlist: []
    ],
    json: [:id, :status, :current_index, :kept, :rejected, :skipped]

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.LibraryPlaylist

  @type t :: %__MODULE__{
          id: integer() | nil,
          status: :pending | :active | :completed,
          current_index: integer(),
          kept: [String.t()],
          rejected: [String.t()],
          skipped: [String.t()],
          user: entity(User.t()),
          origin_playlist: entity(LibraryPlaylist.t()),
          destination_playlist: entity(LibraryPlaylist.t()),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "collection_sessions" do
    field :status, Ecto.Enum, values: [:pending, :active, :completed], default: :pending
    field :current_index, :integer, default: 0

    field :kept, {:array, :string}, default: []
    field :rejected, {:array, :string}, default: []
    field :skipped, {:array, :string}, default: []

    belongs_to :user, User
    belongs_to :origin_playlist, LibraryPlaylist
    belongs_to :destination_playlist, LibraryPlaylist

    timestamps(type: :utc_datetime)
  end

  @doc "Creates changeset for collection session."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :status,
      :current_index,
      :kept,
      :rejected,
      :skipped,
      :user_id,
      :origin_playlist_id,
      :destination_playlist_id
    ])
    |> validate_required([:user_id, :origin_playlist_id, :destination_playlist_id])
    |> validate_inclusion(:status, [:pending, :active, :completed])
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
end
