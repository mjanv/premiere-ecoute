defmodule PremiereEcoute.Sessions.Scores.Vote do
  @moduledoc false

  use PremiereEcoute.Core.Schema

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.Discography.Album.Track
  alias PremiereEcoute.Sessions.ListeningSession

  @type t :: %__MODULE__{
          id: integer() | nil,
          viewer_id: String.t() | nil,
          value: integer() | nil,
          is_streamer: boolean(),
          session: entity(ListeningSession.t()),
          track: entity(Track.t()),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "votes" do
    field :viewer_id, :string
    field :value, :string
    field :is_streamer, :boolean, default: false

    belongs_to :session, ListeningSession
    belongs_to :track, Track

    timestamps(type: :utc_datetime)
  end

  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:viewer_id, :session_id, :track_id, :is_streamer, :value])
    |> validate_required([:viewer_id, :session_id, :track_id, :is_streamer, :value])
    |> unique_constraint([:viewer_id, :session_id, :track_id], name: :vote_index)
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:track_id)
  end

  def from_message(message, vote_options) do
    if message in vote_options do
      {:ok, message}
    else
      {:error, message}
    end
  end

  def from_message(message) do
    from_message(message, ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"])
  end
end
