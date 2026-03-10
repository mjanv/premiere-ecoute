defmodule PremiereEcoute.Collections.CollectionDecision do
  @moduledoc """
  Collection decision aggregate.

  Records the outcome of a track during a collection session. For viewer_vote and duel modes,
  stores the raw vote counts so the streamer can see them before making the final call.
  """

  use PremiereEcouteCore.Aggregate,
    json: [:id, :track_id, :track_name, :artist, :position, :decision, :votes_a, :votes_b, :decided_at]

  alias PremiereEcoute.Collections.CollectionSession
  alias PremiereEcoute.Repo

  @type t :: %__MODULE__{
          id: integer() | nil,
          track_id: String.t(),
          track_name: String.t(),
          artist: String.t(),
          position: integer(),
          decision: :kept | :rejected | :skipped,
          votes_a: integer(),
          votes_b: integer(),
          duel_track_id: String.t() | nil,
          decided_at: DateTime.t() | nil,
          collection_session_id: integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "collection_decisions" do
    field :track_id, :string
    field :track_name, :string
    field :artist, :string
    field :position, :integer
    field :decision, Ecto.Enum, values: [:kept, :rejected, :skipped]
    field :votes_a, :integer, default: 0
    field :votes_b, :integer, default: 0
    field :duel_track_id, :string

    field :decided_at, :utc_datetime

    belongs_to :collection_session, CollectionSession

    timestamps(type: :utc_datetime)
  end

  @doc "Creates changeset for a collection decision."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(decision, attrs) do
    decision
    |> cast(attrs, [
      :track_id,
      :track_name,
      :artist,
      :position,
      :decision,
      :votes_a,
      :votes_b,
      :duel_track_id,
      :decided_at,
      :collection_session_id
    ])
    |> validate_required([:track_id, :track_name, :artist, :position, :decision, :collection_session_id])
    |> validate_inclusion(:decision, [:kept, :rejected, :skipped])
    |> unique_constraint([:collection_session_id, :track_id])
    |> foreign_key_constraint(:collection_session_id)
  end

  @doc "Records a decision for a track."
  @spec decide(integer(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def decide(session_id, attrs) do
    %__MODULE__{}
    |> changeset(
      Map.merge(attrs, %{collection_session_id: session_id, decided_at: DateTime.utc_now() |> DateTime.truncate(:second)})
    )
    |> Repo.insert()
  end

  @doc "Increments vote counts for a given track within a session."
  @spec increment_votes(integer(), String.t(), :a | :b) :: {integer(), nil}
  def increment_votes(session_id, track_id, side) do
    field = if side == :a, do: :votes_a, else: :votes_b

    from(d in __MODULE__,
      where: d.collection_session_id == ^session_id and d.track_id == ^track_id
    )
    |> Repo.update_all(inc: [{field, 1}])
  end

  @doc "Returns all decisions for a session ordered by position."
  @spec all_for_session(integer()) :: [t()]
  def all_for_session(session_id) do
    from(d in __MODULE__,
      where: d.collection_session_id == ^session_id,
      order_by: [asc: d.position]
    )
    |> Repo.all()
  end

  @doc "Returns kept decisions for a session ordered by position."
  @spec kept_for_session(integer()) :: [t()]
  def kept_for_session(session_id) do
    from(d in __MODULE__,
      where: d.collection_session_id == ^session_id and d.decision == :kept,
      order_by: [asc: d.position]
    )
    |> Repo.all()
  end
end
