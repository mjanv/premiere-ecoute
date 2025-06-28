defmodule PremiereEcoute.Core.Commands do
  @moduledoc """
  Command structures for the event-driven architecture.
  Commands represent intentions to change state.
  """

  @type command_id :: String.t()
  @type streamer_id :: String.t()
  @type album_id :: String.t()
  @type session_id :: String.t()
  @type track_id :: String.t()
  @type vote_value :: 1..10

  defmodule SelectAlbum do
    @moduledoc "Command to select an album for a listening session"
    defstruct [:command_id, :streamer_id, :spotify_album_id, :timestamp]

    @type t :: %__MODULE__{
            command_id: PremiereEcoute.Core.Commands.command_id(),
            streamer_id: PremiereEcoute.Core.Commands.streamer_id(),
            spotify_album_id: String.t(),
            timestamp: DateTime.t()
          }
  end

  defmodule StartListening do
    @moduledoc "Command to start a listening session"
    defstruct [:command_id, :streamer_id, :album_id, :timestamp]

    @type t :: %__MODULE__{
            command_id: PremiereEcoute.Core.Commands.command_id(),
            streamer_id: PremiereEcoute.Core.Commands.streamer_id(),
            album_id: PremiereEcoute.Core.Commands.album_id(),
            timestamp: DateTime.t()
          }
  end
end
