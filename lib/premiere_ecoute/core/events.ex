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
end
