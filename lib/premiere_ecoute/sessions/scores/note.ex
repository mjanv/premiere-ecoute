defmodule PremiereEcoute.Sessions.Scores.Note do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  embedded_schema do
    field :entity_id, :binary
    field :unique_votes, :integer
    field :unique_viewers, :integer

    field :viewer_score, :float
    field :streamer_score, :float
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [:entity_id, :unique_votes, :unique_viewers, :viewer_score, :streamer_score])
    |> validate_required([:entity_id])
  end
end
