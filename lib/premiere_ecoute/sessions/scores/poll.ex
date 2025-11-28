defmodule PremiereEcoute.Sessions.Scores.Poll do
  @moduledoc """
  Poll schema and operations

  Manages voting polls associated with listening sessions and tracks. This module provides data persistence for poll results, vote tallying, and validation to ensure vote counts are consistent with totals.
  """

  use PremiereEcouteCore.Aggregate

  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession

  @type t :: %__MODULE__{
          id: integer() | nil,
          poll_id: String.t() | nil,
          title: String.t() | nil,
          total_votes: integer() | nil,
          votes: map() | nil,
          ended_at: NaiveDateTime.t() | nil,
          session: entity(ListeningSession.t()),
          track: entity(Track.t()),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "polls" do
    field :poll_id, :string
    field :title, :string
    field :total_votes, :integer
    field :votes, :map
    field :ended_at, :naive_datetime

    belongs_to :session, ListeningSession
    belongs_to :track, Track

    timestamps()
  end

  @doc """
  Creates changeset for poll with vote validation.

  Validates poll_id, total_votes, votes map, session and track references, ensuring votes sum equals total_votes and poll_id uniqueness per session-track combination.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(poll, attrs) do
    poll
    |> cast(attrs, [:poll_id, :title, :total_votes, :votes, :ended_at, :session_id, :track_id])
    |> validate_required([:poll_id, :total_votes, :votes, :session_id, :track_id])
    |> validate_number(:total_votes, greater_than_or_equal_to: 0)
    |> validate_votes()
    |> unique_constraint([:poll_id])
    |> unique_constraint([:session_id, :track_id], name: :polls_session_track_index)
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:track_id)
  end

  defp validate_votes(changeset) do
    case get_field(changeset, :votes) do
      votes when is_map(votes) ->
        calculated_total = votes |> Map.values() |> Enum.sum()

        if calculated_total == get_field(changeset, :total_votes) do
          changeset
        else
          add_error(changeset, :votes, "vote counts must sum to total_votes")
        end

      _ ->
        add_error(changeset, :votes, "must be a map")
    end
  end

  @doc """
  Creates or updates poll by poll_id.

  Inserts new poll if poll_id doesn't exist, otherwise updates existing poll with new total_votes and votes counts.
  """
  @spec upsert(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def upsert(%__MODULE__{poll_id: poll_id} = poll) when not is_nil(poll_id) do
    case Repo.get_by(__MODULE__, poll_id: poll_id) do
      nil ->
        create(poll)

      p ->
        p
        |> changeset(%{total_votes: poll.total_votes, votes: poll.votes})
        |> Repo.update()
    end
  end
end
