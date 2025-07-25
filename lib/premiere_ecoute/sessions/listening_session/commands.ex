defmodule PremiereEcoute.Sessions.ListeningSession.Commands do
  @moduledoc false

  defmodule PrepareListeningSession do
    @moduledoc false

    @type t :: %__MODULE__{user_id: integer(), album_id: String.t(), vote_options: [String.t()]}

    defstruct [:user_id, :album_id, :vote_options]
  end

  defmodule StartListeningSession do
    @moduledoc false

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: String.t(), scope: Scope.t()}

    defstruct [:session_id, :scope]
  end

  defmodule SkipNextTrackListeningSession do
    @moduledoc false

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: String.t(), scope: Scope.t()}

    defstruct [:session_id, :scope]
  end

  defmodule SkipPreviousTrackListeningSession do
    @moduledoc false

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: String.t(), scope: Scope.t()}

    defstruct [:session_id, :scope]
  end

  defmodule StopListeningSession do
    @moduledoc false

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: String.t(), scope: Scope.t()}

    defstruct [:session_id, :scope]
  end
end
