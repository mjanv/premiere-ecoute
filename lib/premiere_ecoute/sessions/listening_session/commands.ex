defmodule PremiereEcoute.Sessions.ListeningSession.Commands do
  @moduledoc false

  defmodule PrepareListeningSession do
    @moduledoc false

    defstruct [:user_id, :album_id]

    @type t :: %__MODULE__{
            user_id: integer(),
            album_id: String.t()
          }
  end

  defmodule StartListeningSession do
    @moduledoc false

    defstruct [:session_id]

    @type t :: %__MODULE__{
            session_id: String.t()
          }
  end

  defmodule StopListeningSession do
    @moduledoc false

    defstruct [:session_id]

    @type t :: %__MODULE__{
            session_id: String.t()
          }
  end
end
