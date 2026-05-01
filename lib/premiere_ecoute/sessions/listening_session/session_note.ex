defmodule PremiereEcoute.Sessions.ListeningSession.SessionNote do
  @moduledoc false

  use PremiereEcouteCore.Aggregate.Object

  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.TrackMarker

  @type t :: %__MODULE__{
          id: integer() | nil,
          content: String.t(),
          listening_session_id: integer(),
          track_marker_id: integer() | nil
        }

  @primary_key {:id, :id, autogenerate: true}
  schema "session_notes" do
    field :content, :string

    belongs_to :listening_session, ListeningSession
    belongs_to :track_marker, TrackMarker

    timestamps(type: :utc_datetime)
  end

  @doc "Session note changeset."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(note, attrs) do
    note
    |> cast(attrs, [:content, :listening_session_id, :track_marker_id])
    |> validate_required([:content, :listening_session_id])
    |> validate_length(:content, min: 1, max: 1000)
    |> foreign_key_constraint(:listening_session_id)
    |> foreign_key_constraint(:track_marker_id)
  end
end
