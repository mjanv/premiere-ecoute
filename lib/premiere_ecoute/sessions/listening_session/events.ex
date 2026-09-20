defmodule PremiereEcoute.Sessions.ListeningSession.Events do
  @moduledoc """
  Listening session events.
  """

  defmodule SessionPrepared do
    @moduledoc """
    Event - Listening session prepared.
    """

    defstruct [:source, :session_id, :user_id, :album_id, :playlist_id, :single_id]

    @type t :: %__MODULE__{
            source: atom(),
            session_id: String.t(),
            user_id: integer(),
            album_id: String.t() | nil,
            playlist_id: String.t() | nil,
            single_id: integer() | nil
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

    `playback` reports the outcome of the underlying Spotify playback command
    (`:started`, `:failed`, or `nil` when no playback command was issued for
    this source) so it can be surfaced without blocking session start.
    """

    defstruct [:source, :session_id, :user_id, :playback]

    @type t :: %__MODULE__{
            source: atom(),
            session_id: String.t(),
            user_id: integer(),
            playback: :started | :failed | nil
          }
  end

  defmodule NextTrackStarted do
    @moduledoc """
    Event - Next track started in session.

    See `SessionStarted` for the meaning of `playback`.
    """

    defstruct [:source, :session_id, :user_id, :track, :playback]

    @type t :: %__MODULE__{
            source: atom(),
            session_id: String.t(),
            user_id: integer(),
            track: any(),
            playback: :started | :failed | nil
          }
  end

  defmodule PreviousTrackStarted do
    @moduledoc """
    Event - Previous track started in session.

    See `SessionStarted` for the meaning of `playback`.
    """

    defstruct [:session_id, :user_id, :track, :playback]

    @type t :: %__MODULE__{
            session_id: String.t(),
            user_id: integer(),
            track: any(),
            playback: :started | :failed | nil
          }
  end

  defmodule SessionStopped do
    @moduledoc """
    Event - Listening session stopped.

    See `SessionStarted` for the meaning of `playback` (here `:paused` replaces `:started`).
    """

    defstruct [:session_id, :user_id, :playback]

    @type t :: %__MODULE__{session_id: String.t(), user_id: integer(), playback: :paused | :failed | nil}
  end

  defmodule TrackCaptured do
    @moduledoc """
    Event - A track was captured from Spotify playback into a free session.
    """

    defstruct [:session_id, :user_id, :single_id, :track_name, :artist]

    @type t :: %__MODULE__{
            session_id: integer(),
            user_id: integer(),
            single_id: integer(),
            track_name: String.t(),
            artist: String.t()
          }
  end

  defmodule VoteWindowOpened do
    @moduledoc """
    Event - Vote window opened for the current track in a free session.
    """

    defstruct [:session_id, :user_id, :track_id, :vote_mode]

    @type t :: %__MODULE__{
            session_id: integer(),
            user_id: integer(),
            track_id: integer(),
            vote_mode: :chat | :poll
          }
  end

  defmodule VoteWindowClosed do
    @moduledoc """
    Event - Vote window closed in a free session.
    """

    defstruct [:session_id, :user_id, :vote_mode]

    @type t :: %__MODULE__{
            session_id: integer(),
            user_id: integer(),
            vote_mode: :chat | :poll
          }
  end
end
