defmodule PremiereEcoute.Sessions.ListeningSession.EventHandler do
  @moduledoc false

  use PremiereEcoute.Core.CommandBus.Handler,
    events: [
      PremiereEcoute.Sessions.ListeningSession.Events.SessionPrepared,
      PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted,
      PremiereEcoute.Sessions.ListeningSession.Events.SessionStopped
    ]

  def dispatch(_), do: :ok
end
