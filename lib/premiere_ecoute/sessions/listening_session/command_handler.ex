defmodule PremiereEcoute.Sessions.ListeningSession.CommandHandler do
  @moduledoc """
  Command handler for listening session commands.

  Handles session lifecycle commands (prepare/start/stop) and playback navigation (next/previous track), coordinating between Spotify API, Twitch API, and session state management while publishing corresponding events.
  """

  use PremiereEcouteCore.CommandBus.Handler
  use Gettext, backend: PremiereEcoute.Gettext

  require Logger

  alias PremiereEcoute.Apis

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Playlist
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

  command(PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.SkipNextTrackListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.SkipPreviousTrackListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession)

  @doc false
  def handle(%PrepareListeningSession{source: :album, user_id: user_id, album_id: album_id, vote_options: vote_options}) do
    with {:ok, album} <- Apis.spotify().get_album(album_id),
         {:ok, album} <- Album.create_if_not_exists(album),
         {:ok, session} <-
           ListeningSession.create(%{
             user_id: user_id,
             source: :album,
             album_id: album.id,
             vote_options: vote_options || ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
           }) do
      {:ok, session,
       [
         %SessionPrepared{
           session_id: session.id,
           user_id: session.user_id,
           album_id: session.album_id,
           playlist_id: nil
         }
       ]}
    else
      {:error, reason} ->
        Logger.error("Cannot prepare listening session due to: #{inspect(reason)}")
        {:error, [%SessionNotPrepared{user_id: user_id}]}
    end
  end

  def handle(%PrepareListeningSession{source: :playlist, user_id: user_id, playlist_id: playlist_id, vote_options: vote_options}) do
    with {:ok, playlist} <- Apis.spotify().get_playlist(playlist_id),
         {:ok, playlist} <- get_or_create_playlist(playlist),
         {:ok, session} <-
           ListeningSession.create(%{
             user_id: user_id,
             source: :playlist,
             playlist_id: playlist.id,
             vote_options: vote_options || ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
           }) do
      {:ok, session,
       [
         %SessionPrepared{
           session_id: session.id,
           user_id: session.user_id,
           album_id: nil,
           playlist_id: session.playlist_id
         }
       ]}
    else
      {:error, reason} ->
        Logger.error("Cannot prepare listening session due to: #{inspect(reason)}")
        {:error, [%SessionNotPrepared{user_id: user_id}]}
    end
  end

  def handle(%StartListeningSession{source: :album, session_id: session_id, scope: scope}) do
    with {:ok, devices} <- Apis.spotify().devices(scope),
         true <- Enum.any?(devices, fn device -> device["is_active"] end),
         {:ok, _} <- Apis.twitch().resubscribe(scope, "channel.chat.message"),
         session <- ListeningSession.get(session_id),
         {:ok, _} <- Report.generate(session),
         {:ok, %{album: album}} <- ListeningSession.start(session),
         {:ok, _} <- Apis.spotify().toggle_playback_shuffle(scope, false),
         {:ok, _} <- Apis.spotify().set_repeat_mode(scope, :off),
         message <-
           PremiereEcoute.Gettext.t(scope, fn ->
             gettext("Welcome to the premiere of %{name} by %{artist}", name: album.name, artist: album.artist)
           end),
         :ok <- Apis.twitch().send_chat_message(scope, message) do
      {:ok, session, [%SessionStarted{source: :album, session_id: session.id, user_id: scope.user.id}]}
    else
      false ->
        {:error, "No Spotify active device detected"}

      {:error, :active_session_exists} ->
        {:error, "You already have an active listening session"}

      reason ->
        Logger.error("Cannot start listening session due to: #{inspect(reason)}")
        {:error, []}
    end
  end

  def handle(%StartListeningSession{source: :playlist, session_id: session_id, scope: scope}) do
    with {:ok, devices} <- Apis.spotify().devices(scope),
         true <- Enum.any?(devices, fn device -> device["is_active"] end),
         {:ok, _} <- Apis.twitch().resubscribe(scope, "channel.chat.message"),
         session <- ListeningSession.get(session_id),
         {:ok, _} <- Report.generate(session),
         {:ok, session} <- ListeningSession.start(session),
         {:ok, _} <- Apis.spotify().toggle_playback_shuffle(scope, false),
         {:ok, _} <- Apis.spotify().set_repeat_mode(scope, :off),
         _ <- Apis.spotify().start_resume_playback(scope, session.playlist) do
      {:ok, session, [%SessionStarted{source: :playlist, session_id: session.id, user_id: scope.user.id}]}
    else
      false ->
        {:error, "No Spotify active device detected"}

      {:error, :active_session_exists} ->
        {:error, "You already have an active listening session"}

      reason ->
        Logger.error("Cannot start listening session due to: #{inspect(reason)}")
        {:error, []}
    end
  end

  def handle(%SkipNextTrackListeningSession{source: :album, session_id: session_id, scope: scope}) do
    with session <- ListeningSession.get(session_id),
         {:ok, session} <- ListeningSession.next_track(session),
         {:ok, _} <- Apis.spotify().start_resume_playback(scope, session.current_track),
         :ok <-
           Apis.twitch().send_chat_message(
             scope,
             "(#{session.current_track.track_number}/#{session.album.total_tracks}) #{session.current_track.name}"
           ) do
      {:ok, session,
       [%NextTrackStarted{source: :album, session_id: session.id, user_id: scope.user.id, track: session.current_track}]}
    else
      _ -> {:error, []}
    end
  end

  def handle(%SkipNextTrackListeningSession{source: :playlist, session_id: session_id, scope: scope}) do
    with session <- ListeningSession.get(session_id),
         {:ok, _} <- Apis.spotify().next_track(scope) do
      {:ok, session, [%NextTrackStarted{session_id: session.id, user_id: scope.user.id, track: nil}]}
    else
      _ -> {:error, []}
    end
  end

  def handle(%SkipPreviousTrackListeningSession{session_id: session_id, scope: scope}) do
    with session <- ListeningSession.get(session_id),
         {:ok, session} <- ListeningSession.previous_track(session),
         {:ok, _} <- Apis.spotify().start_resume_playback(scope, session.current_track),
         :ok <-
           Apis.twitch().send_chat_message(
             scope,
             "(#{session.current_track.track_number}/#{session.album.total_tracks}) #{session.current_track.name}"
           ) do
      {:ok, session, [%PreviousTrackStarted{session_id: session.id, user_id: scope.user.id, track: session.current_track}]}
    else
      _ -> {:error, []}
    end
  end

  def handle(%StopListeningSession{session_id: session_id, scope: scope}) do
    with {:ok, devices} <- Apis.spotify().devices(scope),
         is_active <- Enum.any?(devices, fn device -> device["is_active"] end),
         session <- ListeningSession.get(session_id),
         {:ok, _} <- Report.generate(session),
         {:ok, _} <- Apis.twitch().unsubscribe(scope, "channel.chat.message"),
         message <-
           PremiereEcoute.Gettext.t(scope, fn -> gettext("The premiere of %{name} is over", name: session.album.name) end),
         :ok <- Apis.twitch().send_chat_message(scope, message),
         {:ok, session} <- ListeningSession.stop(session) do
      if is_active, do: Apis.spotify().pause_playback(scope)
      {:ok, session, [%SessionStopped{session_id: session.id, user_id: scope.user.id}]}
    else
      reason ->
        Logger.error("Cannot stop listening session due to: #{inspect(reason)}")
        {:error, []}
    end
  end

  defp get_or_create_playlist(playlist) do
    case Playlist.get_by(playlist_id: playlist.playlist_id, provider: playlist.provider) do
      nil -> Playlist.create(%{playlist | tracks: [], url: Playlist.url(playlist)})
      existing_playlist -> {:ok, existing_playlist}
    end
  end
end
