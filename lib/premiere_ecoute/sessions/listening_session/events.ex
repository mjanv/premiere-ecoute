defmodule PremiereEcoute.Sessions.ListeningSession.Events do
  @moduledoc false

  defmodule SessionStarted do
    @moduledoc false

    defstruct [:session_id, :streamer_id, :album_id]

    @type t :: %__MODULE__{
            session_id: String.t(),
            streamer_id: String.t(),
            album_id: String.t()
          }
  end

  defmodule SessionNotStarted do
    @moduledoc false

    defstruct [:streamer_id]

    @type t :: %__MODULE__{streamer_id: String.t()}
  end
end
