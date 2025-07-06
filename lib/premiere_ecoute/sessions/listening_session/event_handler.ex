defmodule PremiereEcoute.Sessions.ListeningSession.EventHandler do
  @moduledoc false

  use PremiereEcoute.Core.EventBus.Handler

  event(PremiereEcoute.Sessions.ListeningSession.Events.SessionPrepared)
  event(PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted)
  event(PremiereEcoute.Sessions.ListeningSession.Events.SessionStopped)

  def dispatch(_), do: :ok
end
