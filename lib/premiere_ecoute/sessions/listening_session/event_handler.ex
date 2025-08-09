defmodule PremiereEcoute.Sessions.ListeningSession.EventHandler do
  @moduledoc false

  use PremiereEcouteCore.EventBus.Handler

  event(PremiereEcoute.Sessions.ListeningSession.Events.SessionPrepared)
  event(PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted)
  event(PremiereEcoute.Sessions.ListeningSession.Events.SessionStopped)
  event(PremiereEcoute.Sessions.ListeningSession.Events.NextTrackStarted)
  event(PremiereEcoute.Sessions.ListeningSession.Events.PreviousTrackStarted)

  def dispatch(_), do: :ok
end
