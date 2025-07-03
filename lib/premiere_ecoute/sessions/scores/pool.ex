defmodule PremiereEcoute.Sessions.Scores.Pool do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.Discography.Track
  alias PremiereEcoute.Sessions.ListeningSession

  @type t :: %__MODULE__{
          id: integer(),
          poll_id: String.t(),
          title: String.t(),
          total_votes: integer(),
          votes: map(),
          ended_at: NaiveDateTime.t(),
          session: ListeningSession.t(),
          track: Track.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "pools" do
    field :poll_id, :string
    field :title, :string
    field :total_votes, :integer
    field :votes, :map
    field :ended_at, :naive_datetime

    belongs_to :session, ListeningSession
    belongs_to :track, Track

    timestamps()
  end

  def changeset(pool, attrs) do
    pool
    |> cast(attrs, [:poll_id, :title, :total_votes, :votes, :ended_at, :session_id, :track_id])
    |> validate_required([:poll_id, :total_votes, :votes, :session_id, :track_id])
    |> validate_number(:total_votes, greater_than_or_equal_to: 0)
    |> validate_votes_map()
    |> unique_constraint([:poll_id])
    |> unique_constraint([:session_id, :track_id], name: :pools_session_track_index)
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:track_id)
  end

  defp validate_votes_map(changeset) do
    case get_field(changeset, :votes) do
      votes when is_map(votes) ->
        calculated_total = votes |> Map.values() |> Enum.sum()
        expected_total = get_field(changeset, :total_votes)

        if calculated_total == expected_total do
          changeset
        else
          add_error(changeset, :votes, "vote counts must sum to total_votes")
        end

      _ ->
        add_error(changeset, :votes, "must be a map")
    end
  end

  @spec create(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(%__MODULE__{} = pool) do
    %__MODULE__{}
    |> changeset(Map.from_struct(pool))
    |> Repo.insert()
  end

  @spec get_by(Keyword.t()) :: [t()]
  def get_by(opts) do
    Repo.one(from(p in __MODULE__, where: ^opts))
  end

  @spec all(Keyword.t()) :: [t()]
  def all(opts) do
    from(p in __MODULE__,
      where: ^opts,
      order_by: [asc: p.inserted_at]
    )
    |> Repo.all()
  end
end
