defmodule PremiereEcoute.Core.Entities do
  @moduledoc false

  defmodule ListeningSession do
    @moduledoc "A listening session where streamers and viewers rate an album"
    defstruct [
      :id,
      :streamer_id,
      :album_id,
      :current_track_id,
      :status,
      :started_at,
      :ended_at,
      :inserted_at,
      :updated_at
    ]

    @type status :: :preparing | :active | :stopped
    @type t :: %__MODULE__{
            id: String.t() | nil,
            streamer_id: String.t(),
            album_id: String.t(),
            current_track_id: String.t() | nil,
            status: status(),
            started_at: DateTime.t() | nil,
            ended_at: DateTime.t() | nil,
            inserted_at: DateTime.t() | nil,
            updated_at: DateTime.t() | nil
          }
  end
end
