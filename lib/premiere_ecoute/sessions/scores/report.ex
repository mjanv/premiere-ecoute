defmodule PremiereEcoute.Sessions.Scores.Report do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Note

  schema "reports" do
    belongs_to :session, ListeningSession

    embeds_one :album_note, Note
    embeds_many :track_notes, Note

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(report, attrs) do
    report
    |> cast(attrs, [:session_id])
    |> validate_required([:session_id])
    |> foreign_key_constraint(:session_id)
    |> cast_embed(:album_note, required: true)
    |> cast_embed(:track_notes)
  end
end
