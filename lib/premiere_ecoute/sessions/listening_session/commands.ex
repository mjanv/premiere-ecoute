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
            source: :album | :playlist | :track,
            album_id: String.t() | nil,
            playlist_id: String.t() | nil,
            track_id: String.t() | nil,
            vote_options: [String.t()]
          }

    defstruct [:user_id, :source, :album_id, :playlist_id, :track_id, :vote_options]
  end

  defmodule StartListeningSession do
    @moduledoc """
    Command - Start a listening session.
    """

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: String.t(), source: :album | :playlist | :track, scope: Scope.t(), resume: boolean()}

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

    @type t :: %__MODULE__{session_id: String.t(), source: :album | :playlist | :track, scope: Scope.t()}

    defstruct [:session_id, :source, :scope]
  end
end
