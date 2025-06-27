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
            command_id: command_id,
            streamer_id: streamer_id,
            spotify_album_id: String.t(),
            timestamp: DateTime.t()
          }
  end

  defmodule StartListening do
    @moduledoc "Command to start a listening session"
    defstruct [:command_id, :streamer_id, :album_id, :timestamp]

    @type t :: %__MODULE__{
            command_id: command_id,
            streamer_id: streamer_id,
            album_id: album_id,
            timestamp: DateTime.t()
          }
  end

  defmodule StopListening do
    @moduledoc "Command to stop a listening session"
    defstruct [:command_id, :streamer_id, :session_id, :timestamp]

    @type t :: %__MODULE__{
            command_id: command_id,
            streamer_id: streamer_id,
            session_id: session_id,
            timestamp: DateTime.t()
          }
  end

  defmodule CastVote do
    @moduledoc "Command to cast a vote for a track"
    defstruct [
      :command_id,
      :session_id,
      :track_id,
      :voter_id,
      :vote_value,
      :voter_type,
      :timestamp
    ]

    @type t :: %__MODULE__{
            command_id: command_id,
            session_id: session_id,
            track_id: track_id,
            voter_id: String.t(),
            vote_value: vote_value,
            voter_type: :streamer | :viewer,
            timestamp: DateTime.t()
          }
  end

  defmodule NextTrack do
    @moduledoc "Command to move to the next track in a session"
    defstruct [:command_id, :streamer_id, :session_id, :timestamp]

    @type t :: %__MODULE__{
            command_id: command_id,
            streamer_id: streamer_id,
            session_id: session_id,
            timestamp: DateTime.t()
          }
  end
end
