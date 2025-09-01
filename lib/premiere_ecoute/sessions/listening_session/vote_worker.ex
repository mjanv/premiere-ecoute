defmodule PremiereEcoute.Sessions.ListeningSession.VoteWorker do
  @moduledoc false

  use PremiereEcouteCore.Worker, queue: :sessions

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  # alias PremiereEcoute.Apis
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcouteCore.Cache

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "open", "user_id" => user_id, "session_id" => session_id}}) do
    with scope <- Scope.for_user(User.get(user_id)),
         session <- ListeningSession.get(session_id),
         {:ok, _} <- Cache.put(:sessions, scope.user.twitch.user_id, Map.take(session, [:id, :vote_options, :current_track_id])) do
      # {:ok, _} <- Apis.twitch().send_chat_message(scope, "#{session.current_track.name}"),
      PremiereEcoute.PubSub.broadcast("session:#{session_id}", :vote_open)
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "close", "user_id" => user_id, "session_id" => session_id}}) do
    with scope <- Scope.for_user(User.get(user_id)),
         {:ok, _} <- Cache.del(:sessions, scope.user.twitch.user_id) do
      # {:ok, _} <- Apis.twitch().send_chat_message(scope, "#{session.current_track.name}"),
      PremiereEcoute.PubSub.broadcast("session:#{session_id}", :vote_close)
    end
  end
end
