defmodule PremiereEcoute.Sessions.ListeningSession.Events do
  @moduledoc false

  defmodule SessionPrepared do
    @moduledoc false

    defstruct [:session_id, :user_id, :album_id, :playlist_id]

    @type t :: %__MODULE__{
            session_id: String.t(),
            user_id: integer(),
            album_id: String.t() | nil,
            playlist_id: String.t() | nil
          }
  end

  defmodule SessionNotPrepared do
    @moduledoc false

    defstruct [:user_id]

    @type t :: %__MODULE__{user_id: integer()}
  end

  defmodule SessionStarted do
    @moduledoc false

    defstruct [:source, :session_id, :user_id]

    @type t :: %__MODULE__{source: atom(), session_id: String.t(), user_id: integer()}
  end

  defmodule NextTrackStarted do
    @moduledoc false

    defstruct [:source, :session_id, :user_id, :track]

    @type t :: %__MODULE__{source: atom(), session_id: String.t(), user_id: integer(), track: any()}
  end

  defmodule PreviousTrackStarted do
    @moduledoc false

    defstruct [:session_id, :user_id, :track]

    @type t :: %__MODULE__{session_id: String.t(), user_id: integer(), track: any()}
  end

  defmodule SessionStopped do
    @moduledoc false

    defstruct [:session_id, :user_id]

    @type t :: %__MODULE__{session_id: String.t(), user_id: integer()}
  end
end
