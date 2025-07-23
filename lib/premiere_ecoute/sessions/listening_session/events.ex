defmodule PremiereEcoute.Sessions.ListeningSession.Events do
  @moduledoc false

  defmodule SessionPrepared do
    @moduledoc false

    defstruct [:session_id, :user_id, :album_id]

    @type t :: %__MODULE__{
            session_id: String.t(),
            user_id: integer(),
            album_id: String.t()
          }
  end

  defmodule SessionNotPrepared do
    @moduledoc false

    defstruct [:user_id]

    @type t :: %__MODULE__{user_id: integer()}
  end

  defmodule SessionStarted do
    @moduledoc false

    defstruct [:session_id]

    @type t :: %__MODULE__{session_id: String.t()}
  end

  defmodule NextTrackStarted do
    @moduledoc false

    defstruct [:session_id, :track_id]

    @type t :: %__MODULE__{session_id: String.t(), track_id: String.t()}
  end

  defmodule PreviousTrackStarted do
    @moduledoc false

    defstruct [:session_id, :track_id]

    @type t :: %__MODULE__{session_id: String.t(), track_id: String.t()}
  end

  defmodule SessionStopped do
    @moduledoc false

    defstruct [:session_id]

    @type t :: %__MODULE__{session_id: String.t()}
  end
end
