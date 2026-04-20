defmodule PremiereEcoute.Sessions.ListeningSession.Commands do
  @moduledoc """
  Listening session commands.
  """

  defmodule PrepareListeningSession do
    @moduledoc """
    Command - Prepare a new listening session.
    """

    @type t :: %__MODULE__{
            user_id: integer(),
            source: :album | :playlist | :track | :free,
            album_id: String.t() | nil,
            playlist_id: String.t() | nil,
            track_id: String.t() | nil,
            name: String.t() | nil,
            vote_options: [String.t()],
            vote_mode: :chat | :poll | nil,
            autostart: boolean(),
            interlude_threshold_ms: integer() | nil
          }

    defstruct [
      :user_id,
      :source,
      :album_id,
      :playlist_id,
      :track_id,
      :name,
      :vote_options,
      :vote_mode,
      autostart: true,
      interlude_threshold_ms: nil
    ]
  end

  defmodule StartListeningSession do
    @moduledoc """
    Command - Start a listening session.
    """

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{
            session_id: String.t(),
            source: :album | :playlist | :track | :free,
            scope: Scope.t(),
            resume: boolean()
          }

    defstruct [:session_id, :source, :scope, resume: false]
  end

  defmodule SkipNextTrackListeningSession do
    @moduledoc """
    Command - Skip to next track in listening session.
    """

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: String.t(), source: :album | :playlist, scope: Scope.t()}

    defstruct [:session_id, :source, :scope]
  end

  defmodule SkipPreviousTrackListeningSession do
    @moduledoc """
    Command - Skip to previous track in listening session.
    """

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: String.t(), source: :album | :playlist, scope: Scope.t()}

    defstruct [:session_id, :source, :scope]
  end

  defmodule StopListeningSession do
    @moduledoc """
    Command - Stop a listening session.
    """

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: String.t(), source: :album | :playlist | :track | :free, scope: Scope.t()}

    defstruct [:session_id, :source, :scope]
  end

  defmodule CaptureCurrentTrackListeningSession do
    @moduledoc """
    Command - Capture the currently playing Spotify track into a free session.
    """

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: integer(), scope: Scope.t()}

    defstruct [:session_id, :scope]
  end

  defmodule OpenVoteWindowListeningSession do
    @moduledoc """
    Command - Open the vote window for the current captured track in a free session.
    """

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: integer(), scope: Scope.t()}

    defstruct [:session_id, :scope]
  end

  defmodule CloseVoteWindowListeningSession do
    @moduledoc """
    Command - Close the vote window in a free session.
    """

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: integer(), scope: Scope.t()}

    defstruct [:session_id, :scope]
  end
end
