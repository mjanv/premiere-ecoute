defmodule PremiereEcoute.Collections.CollectionSession.Events do
  @moduledoc "Collection session events."

  defmodule CollectionSessionPrepared do
    @moduledoc "Event - Collection session prepared."

    @type t :: %__MODULE__{session_id: integer(), user_id: integer()}
    defstruct [:session_id, :user_id]
  end

  defmodule CollectionSessionStarted do
    @moduledoc "Event - Collection session started."

    @type t :: %__MODULE__{session_id: integer(), user_id: integer()}
    defstruct [:session_id, :user_id]
  end

  defmodule TrackDecided do
    @moduledoc "Event - A track was decided during a collection session."

    @type t :: %__MODULE__{
            session_id: integer(),
            user_id: integer(),
            track_id: String.t(),
            decision: :kept | :rejected | :skipped
          }

    defstruct [:session_id, :user_id, :track_id, :decision]
  end

  defmodule VoteWindowOpened do
    @moduledoc "Event - A vote window was opened for the current track(s)."

    @type t :: %__MODULE__{
            session_id: integer(),
            user_id: integer(),
            track_id: String.t(),
            duel_track_id: String.t() | nil,
            selection_mode: :viewer_vote | :duel,
            vote_duration: integer()
          }

    defstruct [:session_id, :user_id, :track_id, :duel_track_id, :selection_mode, :vote_duration]
  end

  defmodule VoteWindowClosed do
    @moduledoc "Event - The active vote window was closed."

    @type t :: %__MODULE__{session_id: integer(), user_id: integer(), track_id: String.t()}
    defstruct [:session_id, :user_id, :track_id]
  end

  defmodule CollectionSessionCompleted do
    @moduledoc "Event - Collection session completed and kept tracks synced."

    @type t :: %__MODULE__{session_id: integer(), user_id: integer(), kept_count: integer()}
    defstruct [:session_id, :user_id, :kept_count]
  end
end
