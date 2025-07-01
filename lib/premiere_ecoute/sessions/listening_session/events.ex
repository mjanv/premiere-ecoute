defmodule PremiereEcoute.Sessions.ListeningSession.Events do
  @moduledoc false

  defmodule SessionStarted do
    @moduledoc false

    defstruct [:session_id, :user_id, :album_id]

    @type t :: %__MODULE__{
            session_id: String.t(),
            user_id: integer(),
            album_id: String.t()
          }
  end

  defmodule SessionNotStarted do
    @moduledoc false

    defstruct [:user_id]

    @type t :: %__MODULE__{user_id: integer()}
  end
end
