defmodule PremiereEcoute.Sessions.ListeningSession.SpeechMarker do
  @moduledoc """
  Schema for storing transcribed speech segments detected during a listening session.

  Each marker represents a clean speech segment identified by VAD (Voice Activity Detection),
  transcribed via Whisper. Offsets are stored in milliseconds from session start for direct
  use in CSV/Premiere Pro export without recomputation.
  """

  use PremiereEcouteCore.Aggregate.Object

  alias PremiereEcoute.Sessions.ListeningSession

  @type t :: %__MODULE__{
          id: integer() | nil,
          started_at: DateTime.t(),
          start_ms: integer(),
          end_ms: integer(),
          text: String.t() | nil,
          listening_session_id: integer()
        }

  @primary_key {:id, :id, autogenerate: true}
  schema "speech_markers" do
    # AIDEV-NOTE: started_at is wall-clock UTC — correlate with track_markers to find active track.
    # start_ms/end_ms are offsets from session.started_at, pre-computed for Premiere/CSV export.
    field :started_at, :utc_datetime
    field :start_ms, :integer
    field :end_ms, :integer
    field :text, :string

    belongs_to :listening_session, ListeningSession
  end

  @doc "Speech marker changeset."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(marker, attrs) do
    marker
    |> cast(attrs, [:started_at, :start_ms, :end_ms, :text, :listening_session_id])
    |> validate_required([:started_at, :start_ms, :end_ms, :listening_session_id])
    |> validate_number(:start_ms, greater_than_or_equal_to: 0)
    |> validate_number(:end_ms, greater_than: 0)
    |> validate_end_after_start()
  end

  defp validate_end_after_start(changeset) do
    start_ms = get_field(changeset, :start_ms)
    end_ms = get_field(changeset, :end_ms)

    if start_ms && end_ms && end_ms <= start_ms do
      add_error(changeset, :end_ms, "must be greater than start_ms")
    else
      changeset
    end
  end
end
