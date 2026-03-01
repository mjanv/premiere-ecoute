defmodule PremiereEcoute.Sessions.ListeningSessionWorker do
  @moduledoc """
  Oban worker for listening session background tasks.

  Handles scheduled tasks for opening/closing vote windows, track navigation, vote closing warnings, and promotional message sending with localized content.
  """

  use PremiereEcouteCore.Worker,
    queue: :sessions,
    max_attempts: 1,
    unique: [period: 5, keys: [:action, :session_id]]

  use Gettext, backend: PremiereEcoute.Gettext

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.SkipNextTrackListeningSession
  alias PremiereEcouteCore.Cache

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "open_track", "user_id" => user_id, "session_id" => session_id}}) do
    with scope <- Scope.for_user(User.get(user_id)),
         session <- ListeningSession.get(session_id),
         # AIDEV-NOTE: :track sessions have no current_track_id; use single_id so the vote pipeline accepts messages
         cache_entry <- %{id: session.id, vote_options: session.vote_options, current_track_id: session.single_id},
         {:ok, _} <- Cache.put(:sessions, scope.user.twitch.user_id, cache_entry),
         :ok <-
           Apis.twitch().send_chat_message(
             scope,
             Gettext.with_locale(Atom.to_string(scope.user.profile.language), fn -> gettext("Votes are open !") end)
           ) do
      PremiereEcoute.PubSub.broadcast("session:#{session_id}", :vote_open)
    end

    :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "open_album", "user_id" => user_id, "session_id" => session_id}}) do
    with scope <- Scope.for_user(User.get(user_id)),
         session <- ListeningSession.get(session_id),
         {:ok, _} <- Cache.put(:sessions, scope.user.twitch.user_id, Map.take(session, [:id, :vote_options, :current_track_id])),
         :ok <-
           Apis.twitch().send_chat_message(
             scope,
             Gettext.with_locale(Atom.to_string(scope.user.profile.language), fn -> gettext("Votes are open !") end)
           ) do
      PremiereEcoute.PubSub.broadcast("session:#{session_id}", :vote_open)
    end

    :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "open_playlist", "user_id" => user_id, "session_id" => session_id}}) do
    with scope <- Scope.for_user(User.get(user_id)),
         session <- ListeningSession.get(session_id),
         session <- %{id: session.id, vote_options: session.vote_options, current_track_id: session.current_playlist_track_id},
         {:ok, _} <- Cache.put(:sessions, scope.user.twitch.user_id, session),
         :ok <-
           Apis.twitch().send_chat_message(
             scope,
             Gettext.with_locale(Atom.to_string(scope.user.profile.language), fn -> gettext("Votes are open !") end)
           ) do
      PremiereEcoute.PubSub.broadcast("session:#{session_id}", :vote_open)
    end

    :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "votes_closing", "user_id" => user_id}}) do
    scope = Scope.for_user(User.get(user_id))

    Apis.twitch().send_chat_message(
      scope,
      Gettext.with_locale(Atom.to_string(scope.user.profile.language), fn -> gettext("Votes close in 30 seconds !") end)
    )

    :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "close", "user_id" => user_id, "session_id" => session_id}}) do
    with scope <- Scope.for_user(User.get(user_id)),
         {:ok, _} <- Cache.del(:sessions, scope.user.twitch.user_id) do
      PremiereEcoute.PubSub.broadcast("session:#{session_id}", :vote_close)
    end

    :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "next_track", "user_id" => user_id, "session_id" => session_id}}) do
    with scope <- Scope.for_user(User.get(user_id)),
         {:ok, session, _} <-
           PremiereEcoute.apply(%SkipNextTrackListeningSession{source: :album, session_id: session_id, scope: scope}) do
      PremiereEcoute.PubSub.broadcast("session:#{session_id}", {:session_updated, session})
    end

    :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "next_playlist_track", "user_id" => user_id, "session_id" => session_id}}) do
    with scope <- Scope.for_user(User.get(user_id)),
         {:ok, session, _} <-
           PremiereEcoute.apply(%SkipNextTrackListeningSession{source: :playlist, session_id: session_id, scope: scope}) do
      PremiereEcoute.PubSub.broadcast("session:#{session_id}", {:session_updated, session})
    end

    :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "send_promo_message", "user_id" => user_id}}) do
    scope = Scope.for_user(User.get(user_id))

    Apis.twitch().send_chat_message(
      scope,
      Gettext.with_locale(Atom.to_string(scope.user.profile.language), fn ->
        gettext("You can retrieve all your notes by registering to premiere-ecoute.fr using your Twitch account")
      end)
    )

    :ok
  end
end
