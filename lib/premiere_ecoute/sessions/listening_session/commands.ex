defmodule PremiereEcoute.Sessions.ListeningSession.Commands do
  @moduledoc false

  defmodule PrepareListeningSession do
    @moduledoc false

    @type t :: %__MODULE__{
            user_id: integer(),
            source: :album | :playlist,
            album_id: String.t() | nil,
            playlist_id: String.t() | nil,
            vote_options: [String.t()]
          }

    defstruct [:user_id, :source, :album_id, :playlist_id, :vote_options]
  end

  defmodule StartListeningSession do
    @moduledoc false

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: String.t(), source: :album | :playlist, scope: Scope.t()}

    defstruct [:session_id, :source, :scope]
  end

  defmodule SkipNextTrackListeningSession do
    @moduledoc false

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: String.t(), source: :album | :playlist, scope: Scope.t()}

    defstruct [:session_id, :source, :scope]
  end

  defmodule SkipPreviousTrackListeningSession do
    @moduledoc false

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: String.t(), source: :album | :playlist, scope: Scope.t()}

    defstruct [:session_id, :source, :scope]
  end

  defmodule StopListeningSession do
    @moduledoc false

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: String.t(), source: :album | :playlist, scope: Scope.t()}

    defstruct [:session_id, :source, :scope]
  end
end
