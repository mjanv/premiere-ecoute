defmodule PremiereEcoute.Sessions.ListeningSession.CommandHandler do
  @moduledoc false

  use PremiereEcouteCore.CommandBus.Handler
  use Gettext, backend: PremiereEcoute.Gettext

  require Logger

  alias PremiereEcoute.Apis

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.SkipNextTrackListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.SkipPreviousTrackListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Events.NextTrackStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.PreviousTrackStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionNotPrepared
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionPrepared
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStopped
  alias PremiereEcoute.Sessions.Retrospective.Report

  alias PremiereEcoute.Gettext

  command(PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.SkipNextTrackListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.SkipPreviousTrackListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession)

  def handle(%PrepareListeningSession{user_id: user_id, album_id: album_id, vote_options: vote_options}) do
    with {:ok, album} <- Apis.spotify().get_album(album_id),
         {:ok, album} <- Album.create_if_not_exists(album),
         {:ok, session} <-
           ListeningSession.create(%{
             user_id: user_id,
             album_id: album.id,
             vote_options: vote_options || ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
           }) do
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
    with {:ok, _} <- Apis.twitch().cancel_all_subscriptions(scope),
         {:ok, _} <- Apis.twitch().subscribe(scope, "channel.chat.message"),
         session <- ListeningSession.get(session_id),
         {:ok, _} <- Report.generate(session),
         {:ok, _} <- Apis.twitch().send_chat_message(scope, Gettext.gettext(gettext_noop("Welcome !"))),
         {:ok, session} <- ListeningSession.next_track(session),
         {:ok, _} <- Apis.spotify().start_resume_playback(scope, session.current_track),
         {:ok, session} <- ListeningSession.start(session) do
      {:ok, session, [%SessionStarted{session_id: session.id}]}
    else
      reason ->
        Logger.error("Cannot start listening session due to: #{inspect(reason)}")
        {:error, []}
    end
  end

  def handle(%SkipNextTrackListeningSession{session_id: session_id, scope: scope}) do
    with session <- ListeningSession.get(session_id),
         {:ok, session} <- ListeningSession.next_track(session),
         {:ok, _} <- Apis.spotify().start_resume_playback(scope, session.current_track),
         {:ok, _} <- Apis.twitch().send_chat_message(scope, "#{session.current_track.name}"),
         :ok <- PremiereEcoute.PubSub.broadcast("session:#{session_id}", {:next_track, session.current_track}) do
      {:ok, session, [%NextTrackStarted{session_id: session.id, track_id: session.current_track.id}]}
    else
      _ -> {:error, []}
    end
  end

  def handle(%SkipPreviousTrackListeningSession{session_id: session_id, scope: scope}) do
    with session <- ListeningSession.get(session_id),
         {:ok, session} <- ListeningSession.previous_track(session),
         {:ok, _} <- Apis.spotify().start_resume_playback(scope, session.current_track),
         {:ok, _} <- Apis.twitch().send_chat_message(scope, "#{session.current_track.name}"),
         :ok <- PremiereEcoute.PubSub.broadcast("session:#{session_id}", {:previous_track, session.current_track}) do
      {:ok, session, [%PreviousTrackStarted{session_id: session.id, track_id: session.current_track.id}]}
    else
      _ -> {:error, []}
    end
  end

  def handle(%StopListeningSession{session_id: session_id, scope: scope}) do
    with session <- ListeningSession.get(session_id),
         {:ok, _} <- Report.generate(session),
         {:ok, _} <- Apis.spotify().pause_playback(scope),
         {:ok, _} <- Apis.twitch().cancel_all_subscriptions(scope),
         {:ok, _} <- Apis.twitch().send_chat_message(scope, "Good bye !"),
         {:ok, session} <- ListeningSession.stop(session),
         :ok <- PremiereEcoute.PubSub.broadcast("session:#{session_id}", :stop) do
      {:ok, session, [%SessionStopped{session_id: session.id}]}
    else
      reason ->
        Logger.error("Cannot stop listening session due to: #{inspect(reason)}")
        {:error, []}
    end
  end
end
