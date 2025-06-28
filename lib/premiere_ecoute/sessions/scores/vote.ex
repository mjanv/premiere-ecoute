defmodule PremiereEcoute.Sessions.Scores.Vote do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias PremiereEcoute.Discography.Track
  alias PremiereEcoute.Sessions.ListeningSession

  schema "votes" do
    field :viewer_id, :string
    field :value, :integer, default: 1
    field :streamer?, :boolean, default: false

    belongs_to :session, ListeningSession
    belongs_to :track, Track

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:viewer_id, :session_id, :track_id])
    |> validate_required([:viewer_id, :session_id, :track_id])
    |> unique_constraint([:viewer_id, :session_id, :track_id], name: :vote_index)
  end
end
