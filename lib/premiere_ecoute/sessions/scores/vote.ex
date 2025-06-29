defmodule PremiereEcoute.Sessions.Scores.Vote do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias PremiereEcoute.Discography.Track
  alias PremiereEcoute.Repo
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
    |> cast(attrs, [:viewer_id, :session_id, :track_id, :streamer?, :value])
    |> validate_required([:viewer_id, :session_id, :track_id, :streamer?, :value])
    |> unique_constraint([:viewer_id, :session_id, :track_id], name: :vote_index)
  end

  def add(%__MODULE__{} = vote) do
    %__MODULE__{}
    |> changeset(Map.from_struct(vote))
    |> Repo.insert()
  end

  def listening_session_votes(session_id) do
    Repo.all(from(ls in __MODULE__, where: ls.session_id == ^session_id))
  end
end
