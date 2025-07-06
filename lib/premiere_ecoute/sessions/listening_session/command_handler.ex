defmodule PremiereEcoute.Sessions.ListeningSession.CommandHandler do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.TwitchApi

  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionNotPrepared
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionPrepared
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStopped
  alias PremiereEcoute.Sessions.Scores.Report

  use PremiereEcoute.Core.CommandBus.Handler

  command(PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession)

  def handle(%PrepareListeningSession{user_id: user_id, album_id: album_id}) do
    with {:ok, album} <- SpotifyApi.impl().get_album(album_id),
         {:ok, album} <- Album.get_or_create(album),
         {:ok, session} <- ListeningSession.create(%{user_id: user_id, album_id: album.id}) do
      {:ok, session,
       [
         %SessionPrepared{
           session_id: session.id,
           user_id: session.user_id,
           album_id: session.album_id
         }
       ]}
    else
      {:error, reason} ->
        Logger.error("Cannot prepare listening session due to: #{inspect(reason)}")
        {:error, [%SessionNotPrepared{user_id: user_id}]}
    end
  end

  def handle(%StartListeningSession{session_id: session_id, scope: scope}) do
    with session <- ListeningSession.get(session_id),
         {:ok, session} <- ListeningSession.next_track(session),
         {:ok, _} <- TwitchApi.impl().cancel_all_subscriptions(scope),
         {:ok, _} <- TwitchApi.impl().subscribe(scope, "channel.chat.message"),
         {:ok, _} <- TwitchApi.impl().subscribe(scope, "channel.poll.progress"),
         {:ok, _} <- TwitchApi.impl().send_chat_announcement(scope, "Bienvenue !", "purple"),
         {:ok, session} <- ListeningSession.start(session) do
      {:ok, session, [%SessionStarted{session_id: session.id}]}
    else
      reason ->
        Logger.error("Cannot start listening session due to: #{inspect(reason)}")
        {:error, []}
    end
  end

  def handle(%StopListeningSession{session_id: session_id, scope: scope}) do
    with session <- ListeningSession.get(session_id),
         {:ok, _} <- Report.generate(session),
         {:ok, _} <- TwitchApi.impl().cancel_all_subscriptions(scope),
         {:ok, session} <- ListeningSession.stop(session) do
      {:ok, session, [%SessionStopped{session_id: session.id}]}
    else
      reason ->
        Logger.error("Cannot stop listening session due to: #{inspect(reason)}")
        {:error, []}
    end
  end
end
