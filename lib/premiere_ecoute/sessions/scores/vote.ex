defmodule PremiereEcoute.Sessions.Scores.Vote do
  @moduledoc false

  use PremiereEcoute.Core.Schema

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.Discography.Track
  alias PremiereEcoute.Sessions.ListeningSession

  @type t :: %__MODULE__{
          id: integer() | nil,
          viewer_id: String.t() | nil,
          value: integer() | nil,
          is_streamer: boolean(),
          session: ListeningSession.t() | nil | Ecto.Association.NotLoaded.t(),
          track: Track.t() | nil | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "votes" do
    field :viewer_id, :string
    field :value, :integer, default: 1
    field :is_streamer, :boolean, default: false

    belongs_to :session, ListeningSession
    belongs_to :track, Track

    timestamps(type: :utc_datetime)
  end

  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:viewer_id, :session_id, :track_id, :is_streamer, :value])
    |> validate_required([:viewer_id, :session_id, :track_id, :is_streamer, :value])
    |> validate_number(:value, greater_than_or_equal_to: 0)
    |> unique_constraint([:viewer_id, :session_id, :track_id], name: :vote_index)
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:track_id)
  end

  def from_message(message) do
    case Integer.parse(message) do
      {integer, _} when integer >= 0 and integer <= 10 -> {:ok, integer}
      _ -> {:error, message}
    end
  end
end
