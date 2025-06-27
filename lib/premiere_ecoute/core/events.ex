defmodule PremiereEcoute.Core.Events do
  @moduledoc """
  Event structures for the event-driven architecture.
  Events represent things that have happened in the system.
  """

  @type event_id :: String.t()
  @type streamer_id :: String.t()
  @type album_id :: String.t()
  @type session_id :: String.t()
  @type track_id :: String.t()
  @type vote_value :: 1..10

  defmodule AlbumSelected do
    @moduledoc "Event fired when an album is selected"
    defstruct [:event_id, :streamer_id, :album, :timestamp]

    @type t :: %__MODULE__{
            event_id: PremiereEcoute.Core.Events.event_id(),
            streamer_id: PremiereEcoute.Core.Events.streamer_id(),
            album: PremiereEcoute.Core.Entities.Album.t(),
            timestamp: DateTime.t()
          }
  end

  defmodule SessionStarted do
    @moduledoc "Event fired when a listening session starts"
    defstruct [:event_id, :session_id, :streamer_id, :album_id, :timestamp]

    @type t :: %__MODULE__{
            event_id: PremiereEcoute.Core.Events.event_id(),
            session_id: PremiereEcoute.Core.Events.session_id(),
            streamer_id: PremiereEcoute.Core.Events.streamer_id(),
            album_id: PremiereEcoute.Core.Events.album_id(),
            timestamp: DateTime.t()
          }
  end

  defmodule SessionStopped do
    @moduledoc "Event fired when a listening session stops"
    defstruct [:event_id, :session_id, :streamer_id, :timestamp]

    @type t :: %__MODULE__{
            event_id: PremiereEcoute.Core.Events.event_id(),
            session_id: PremiereEcoute.Core.Events.session_id(),
            streamer_id: PremiereEcoute.Core.Events.streamer_id(),
            timestamp: DateTime.t()
          }
  end

  defmodule VoteCast do
    @moduledoc "Event fired when a vote is cast"
    defstruct [
      :event_id,
      :session_id,
      :track_id,
      :voter_id,
      :vote_value,
      :voter_type,
      :timestamp
    ]

    @type t :: %__MODULE__{
            event_id: PremiereEcoute.Core.Events.event_id(),
            session_id: PremiereEcoute.Core.Events.session_id(),
            track_id: PremiereEcoute.Core.Events.track_id(),
            voter_id: String.t(),
            vote_value: PremiereEcoute.Core.Events.vote_value(),
            voter_type: :streamer | :viewer,
            timestamp: DateTime.t()
          }
  end

  defmodule TrackProgressed do
    @moduledoc "Event fired when moving to the next track"
    defstruct [:event_id, :session_id, :current_track_id, :next_track_id, :timestamp]

    @type t :: %__MODULE__{
            event_id: PremiereEcoute.Core.Events.event_id(),
            session_id: PremiereEcoute.Core.Events.session_id(),
            current_track_id: PremiereEcoute.Core.Events.track_id(),
            next_track_id: PremiereEcoute.Core.Events.track_id() | nil,
            timestamp: DateTime.t()
          }
  end
end
