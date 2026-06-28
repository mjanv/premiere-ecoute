defmodule PremiereEcoute.Sessions.Services.MissedSessionNotification do
  @moduledoc """
  Enqueues missed-session notification jobs for the followers who cast no vote in a stopped session.
  """

  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Workers.MissedSessionNotificationWorker

  @spec notify(ListeningSession.t() | integer()) :: {:ok, list()}
  def notify(%ListeningSession{id: session_id} = session) do
    session
    |> ListeningSession.followers_who_missed()
    |> Enum.map(&%{"user_id" => &1, "session_id" => session_id})
    |> MissedSessionNotificationWorker.start()
  end

  def notify(session_id) when is_integer(session_id) do
    session_id
    |> ListeningSession.get()
    |> notify()
  end
end
