defmodule PremiereEcoute.Sessions.ListeningSession.Commands do
  @moduledoc false

  defmodule StartListeningSession do
    @moduledoc false

    defstruct [:streamer_id, :album_id]

    @type t :: %__MODULE__{
            streamer_id: String.t(),
            album_id: String.t()
          }
  end
end
