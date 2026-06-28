defmodule PremiereEcoute.Sessions.ListeningSession.Workers.MissedSessionNotificationWorker do
  @moduledoc """
  Sends a missed-session notification to a single follower.
  """

  use PremiereEcouteCore.Worker, queue: :notifications, max_attempts: 5

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Notifications
  alias PremiereEcoute.Notifications.Types.MissedSession
  alias PremiereEcoute.Sessions.ListeningSession

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "session_id" => session_id}}) do
    with %User{} = follower <- User.get(user_id),
         %ListeningSession{} = session <- ListeningSession.get(session_id),
         {:ok, _} <-
           Notifications.dispatch(follower, %MissedSession{
             streamer_name: session.user.username,
             session_title: session_title(session),
             username: session.user.username,
             share_token: session.share_token
           }) do
      :ok
    else
      nil -> {:error, :not_found}
      {:error, _} = err -> err
    end
  end

  defp session_title(%ListeningSession{album: %{artists: [%{name: artist} | _]}} = session),
    do: "#{ListeningSession.title(session)} by #{artist}"

  defp session_title(%ListeningSession{single: %{artists: [%{name: artist} | _]}} = session),
    do: "#{ListeningSession.title(session)} by #{artist}"

  defp session_title(session), do: ListeningSession.title(session)
end
