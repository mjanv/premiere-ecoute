defmodule PremiereEcoute.Sessions.Scores.Vote do
  @moduledoc false

  use PremiereEcoute.Core.Schema,
    json: [:value, :track_id, :session_id, :viewer_id, :inserted_at]

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession

  @type t :: %__MODULE__{
          id: integer() | nil,
          viewer_id: String.t() | nil,
          track_id: String.t() | nil,
          value: integer() | nil,
          is_streamer: boolean(),
          session: entity(ListeningSession.t()),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "votes" do
    field :viewer_id, :string
    field :track_id, :id
    field :value, :string
    field :is_streamer, :boolean, default: false

    belongs_to :session, ListeningSession

    timestamps(type: :utc_datetime)
  end

  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:viewer_id, :session_id, :track_id, :is_streamer, :value])
    |> validate_required([:viewer_id, :session_id, :track_id, :is_streamer, :value])
    |> hash_viewer_id()
    |> unique_constraint([:viewer_id, :session_id, :track_id], name: :vote_index)
    |> foreign_key_constraint(:session_id)
  end

  defp hash_viewer_id(changeset) do
    case get_change(changeset, :viewer_id) do
      nil -> changeset
      id -> put_change(changeset, :viewer_id, hash(id, get_field(changeset, :session_id)))
    end
  end

  def get_by(query, clauses) do
    clauses = Keyword.update(clauses, :viewer_id, nil, fn id -> hash(id, clauses[:session_id]) end)

    super(query, clauses)
  end

  def all(clauses) do
    clauses =
      Keyword.update(clauses, :where, [], fn where ->
        if where[:viewer_id] do
          Keyword.update(where, :viewer_id, nil, fn id -> hash(id, where[:session_id]) end)
        else
          where
        end
      end)

    super(clauses)
  end

  def hash(viewer_id, session_id) do
    Base.encode64(:crypto.hash(:sha256, "#{viewer_id}:#{session_id}"), case: :lower)
  end

  def from_message(message, vote_options) do
    if message in vote_options, do: {:ok, message}, else: {:error, message}
  end

  def from_message(message) do
    from_message(message, ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"])
  end
end
