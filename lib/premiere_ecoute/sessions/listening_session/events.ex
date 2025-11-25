defmodule PremiereEcoute.Sessions.ListeningSession.Events do
  @moduledoc """
  Listening session events.
  """

  defmodule SessionPrepared do
    @moduledoc """
    Event - Listening session prepared.
    """

    defstruct [:session_id, :user_id, :album_id, :playlist_id]

    @type t :: %__MODULE__{
            session_id: String.t(),
            user_id: integer(),
            album_id: String.t() | nil,
            playlist_id: String.t() | nil
          }
  end

  defmodule SessionNotPrepared do
    @moduledoc """
    Event - Listening session not prepared.
    """

    defstruct [:user_id]

    @type t :: %__MODULE__{user_id: integer()}
  end

  defmodule SessionStarted do
    @moduledoc """
    Event - Listening session started.
    """

    defstruct [:source, :session_id, :user_id]

    @type t :: %__MODULE__{source: atom(), session_id: String.t(), user_id: integer()}
  end

  defmodule NextTrackStarted do
    @moduledoc """
    Event - Next track started in session.
    """

    defstruct [:source, :session_id, :user_id, :track]

    @type t :: %__MODULE__{source: atom(), session_id: String.t(), user_id: integer(), track: any()}
  end

  defmodule PreviousTrackStarted do
    @moduledoc """
    Event - Previous track started in session.
    """

    defstruct [:session_id, :user_id, :track]

    @type t :: %__MODULE__{session_id: String.t(), user_id: integer(), track: any()}
  end

  defmodule SessionStopped do
    @moduledoc """
    Event - Listening session stopped.
    """

    defstruct [:session_id, :user_id]

    @type t :: %__MODULE__{session_id: String.t(), user_id: integer()}
  end
end
