defmodule PremiereEcoute.Sessions.ListeningSessionWorker do
  @moduledoc false

  use PremiereEcouteCore.Worker, queue: :sessions, max_attempts: 1
  use Gettext, backend: PremiereEcoute.Gettext

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.SkipNextTrackListeningSession
  alias PremiereEcouteCore.Cache

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "open_album", "user_id" => user_id, "session_id" => session_id}}) do
    with scope <- Scope.for_user(User.get(user_id)),
         session <- ListeningSession.get(session_id),
         {:ok, _} <- Cache.put(:sessions, scope.user.twitch.user_id, Map.take(session, [:id, :vote_options, :current_track_id])),
         _ <-
           Apis.twitch().send_chat_message(
             scope,
             Gettext.with_locale(Atom.to_string(scope.user.profile.language), fn -> gettext("Votes are open !") end)
           ) do
      PremiereEcoute.PubSub.broadcast("session:#{session_id}", :vote_open)
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "open_playlist", "user_id" => user_id, "session_id" => session_id}}) do
    with scope <- Scope.for_user(User.get(user_id)),
         session <- ListeningSession.get(session_id),
         session <- %{id: session.id, vote_options: session.vote_options, current_track_id: session.current_playlist_track_id},
         {:ok, _} <- Cache.put(:sessions, scope.user.twitch.user_id, session),
         _ <-
           Apis.twitch().send_chat_message(
             scope,
             Gettext.with_locale(Atom.to_string(scope.user.profile.language), fn -> gettext("Votes are open !") end)
           ) do
      PremiereEcoute.PubSub.broadcast("session:#{session_id}", :vote_open)
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "votes_closing", "user_id" => user_id}}) do
    with scope <- Scope.for_user(User.get(user_id)),
         _ <-
           Apis.twitch().send_chat_message(
             scope,
             Gettext.with_locale(Atom.to_string(scope.user.profile.language), fn -> gettext("Votes close in 30 seconds !") end)
           ) do
      :ok
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "close", "user_id" => user_id, "session_id" => session_id}}) do
    with scope <- Scope.for_user(User.get(user_id)),
         {:ok, _} <- Cache.del(:sessions, scope.user.twitch.user_id) do
      PremiereEcoute.PubSub.broadcast("session:#{session_id}", :vote_close)
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "pause", "user_id" => user_id, "session_id" => _session_id}}) do
    with scope <- Scope.for_user(User.get(user_id)),
         {:ok, _} <- Apis.spotify().pause_playback(scope) do
      :ok
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "next_track", "user_id" => user_id, "session_id" => session_id}}) do
    with scope <- Scope.for_user(User.get(user_id)),
         {:ok, session, _} <-
           PremiereEcoute.apply(%SkipNextTrackListeningSession{source: :album, session_id: session_id, scope: scope}) do
      PremiereEcoute.PubSub.broadcast("session:#{session_id}", {:session_updated, session})
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "next_playlist_track", "user_id" => user_id, "session_id" => session_id}}) do
    with scope <- Scope.for_user(User.get(user_id)),
         {:ok, session, _} <-
           PremiereEcoute.apply(%SkipNextTrackListeningSession{source: :playlist, session_id: session_id, scope: scope}) do
      PremiereEcoute.PubSub.broadcast("session:#{session_id}", {:session_updated, session})
    end
  end
end
