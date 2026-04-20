defmodule PremiereEcoute.Sessions.ListeningSession.CommandHandler do
  @moduledoc """
  Command handler for listening session commands.

  Handles session lifecycle commands (prepare/start/stop) and playback navigation (next/previous track), coordinating between Spotify API, Twitch API, and session state management while publishing corresponding events.
  """

  use PremiereEcouteCore.CommandBus.Handler
  use Gettext, backend: PremiereEcoute.Gettext

  require Logger

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Services.EnrichDiscography
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.CaptureCurrentTrackListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.CloseVoteWindowListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.OpenVoteWindowListeningSession
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
  alias PremiereEcoute.Sessions.ListeningSession.Events.TrackCaptured
  alias PremiereEcoute.Sessions.ListeningSession.Events.VoteWindowClosed
  alias PremiereEcoute.Sessions.ListeningSession.Events.VoteWindowOpened
  alias PremiereEcoute.Sessions.Retrospective.Report

  command(PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.SkipNextTrackListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.SkipPreviousTrackListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.CaptureCurrentTrackListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.OpenVoteWindowListeningSession)
  command(PremiereEcoute.Sessions.ListeningSession.Commands.CloseVoteWindowListeningSession)

  @doc false
  def handle(%PrepareListeningSession{
        source: :album,
        user_id: user_id,
        album_id: album_id,
        vote_options: vote_options,
        autostart: autostart,
        interlude_threshold_ms: interlude_threshold_ms
      }) do
    with {:ok, album} <- EnrichDiscography.create_album(album_id, :spotify),
         {:ok, session} <-
           ListeningSession.create(%{
             user_id: user_id,
             source: :album,
             album_id: album.id,
             vote_options: vote_options || ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"],
             options: %{
               "votes" => 0,
               "scores" => 0,
               "next_track" => 0,
               "autostart" => autostart,
               "interlude_threshold_ms" => interlude_threshold_ms
             }
           }) do
      {:ok, session,
       [
         %SessionPrepared{
           source: :album,
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

  def handle(%PrepareListeningSession{
        source: :track,
        user_id: user_id,
        track_id: track_id,
        vote_options: vote_options,
        autostart: autostart
      }) do
    with {:ok, single} <- EnrichDiscography.create_single(track_id, :spotify),
         {:ok, session} <-
           ListeningSession.create(%{
             user_id: user_id,
             source: :track,
             single_id: single.id,
             vote_options: vote_options || ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"],
             options: %{"votes" => 0, "scores" => 0, "next_track" => 0, "autostart" => autostart}
           }) do
      {:ok, session,
       [
         %SessionPrepared{
           source: :track,
           session_id: session.id,
           user_id: session.user_id,
           single_id: session.single_id
         }
       ]}
    else
      {:error, reason} ->
        Logger.error("Cannot prepare listening session due to: #{inspect(reason)}")
        {:error, [%SessionNotPrepared{user_id: user_id}]}
    end
  end

  def handle(%PrepareListeningSession{
        source: :playlist,
        user_id: user_id,
        playlist_id: playlist_id,
        vote_options: vote_options,
        autostart: autostart,
        interlude_threshold_ms: interlude_threshold_ms
      }) do
    with {:ok, playlist} <- Apis.spotify().get_playlist(playlist_id),
         {:ok, playlist} <- get_or_create_playlist(playlist),
         {:ok, session} <-
           ListeningSession.create(%{
             user_id: user_id,
             source: :playlist,
             playlist_id: playlist.id,
             vote_options: vote_options || ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"],
             options: %{
               "votes" => 0,
               "scores" => 0,
               "next_track" => 0,
               "autostart" => autostart,
               "interlude_threshold_ms" => interlude_threshold_ms
             }
           }) do
      {:ok, session,
       [
         %SessionPrepared{
           source: :playlist,
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

  def handle(%StartListeningSession{source: :track, session_id: session_id, scope: scope, resume: resume}) do
    with {:ok, devices} <- Apis.spotify().devices(scope),
         true <- Enum.any?(devices, fn device -> device["is_active"] end),
         {:ok, _} <- Apis.twitch().resubscribe(scope, "channel.chat.message"),
         session <- ListeningSession.get(session_id),
         {:ok, _} <- Report.generate(session),
         {:ok, %{single: single} = session} <- ListeningSession.start(session),
         {:ok, _} <- maybe_start_playback(resume, scope, single),
         message <-
           PremiereEcoute.Gettext.t(scope, fn ->
             gettext("Welcome to the premiere of %{name} by %{artist}", name: single.name, artist: single.artist)
           end),
         :ok <- Apis.twitch().send_chat_message(scope, message) do
      {:ok, session, [%SessionStarted{source: :track, session_id: session.id, user_id: scope.user.id}]}
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
             gettext("Welcome to the premiere of %{name} by %{artist} (%{tracks} tracks - %{timer})",
               name: album.name,
               artist: album.artist,
               tracks: album.total_tracks,
               timer: PremiereEcouteCore.Duration.timer(Album.total_duration(album))
             )
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
             "[#{session.current_track.track_number}/#{session.album.total_tracks}] #{session.current_track.name} (#{PremiereEcouteCore.Duration.timer(session.current_track.duration_ms)})"
           ) do
      {:ok, session,
       [%NextTrackStarted{source: :album, session_id: session.id, user_id: scope.user.id, track: session.current_track}]}
    else
      _ -> {:error, []}
    end
  end

  def handle(%SkipNextTrackListeningSession{source: :playlist, session_id: session_id, scope: scope}) do
    with session <- ListeningSession.get(session_id),
         {:ok, session} <- ListeningSession.next_track(session),
         {:ok, _} <- Apis.spotify().start_resume_playback(scope, session.current_playlist_track) do
      {:ok, session,
       [
         %NextTrackStarted{
           source: :playlist,
           session_id: session.id,
           user_id: scope.user.id,
           track: session.current_playlist_track
         }
       ]}
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
             "[#{session.current_track.track_number}/#{session.album.total_tracks}] #{session.current_track.name} (#{PremiereEcouteCore.Duration.timer(session.current_track.duration_ms)})"
           ) do
      {:ok, session, [%PreviousTrackStarted{session_id: session.id, user_id: scope.user.id, track: session.current_track}]}
    else
      _ -> {:error, []}
    end
  end

  def handle(%StopListeningSession{source: :track, session_id: session_id, scope: scope}) do
    with session <- ListeningSession.get(session_id),
         {:ok, _} <- Report.generate(session),
         message <-
           PremiereEcoute.Gettext.t(scope, fn ->
             gettext("%{name} by %{artist} is over", name: session.single.name, artist: session.single.artist)
           end),
         :ok <- Apis.twitch().send_chat_message(scope, message),
         {:ok, session} <- ListeningSession.stop(session) do
      {:ok, session, [%SessionStopped{session_id: session.id, user_id: scope.user.id}]}
    else
      reason ->
        Logger.error("Cannot stop listening session due to: #{inspect(reason)}")
        {:error, []}
    end
  end

  def handle(%StopListeningSession{source: :album, session_id: session_id, scope: scope}) do
    with session <- ListeningSession.get(session_id),
         {:ok, _} <- Report.generate(session),
         {:ok, _} <- Apis.twitch().unsubscribe(scope, "channel.chat.message"),
         message <-
           PremiereEcoute.Gettext.t(scope, fn -> gettext("The premiere of %{name} is over", name: session.album.name) end),
         :ok <- Apis.twitch().send_chat_message(scope, message),
         {:ok, session} <- ListeningSession.stop(session) do
      {:ok, devices} = Apis.spotify().devices(scope)
      is_active = Enum.any?(devices, fn device -> device["is_active"] end)
      if is_active, do: Apis.spotify().pause_playback(scope)
      {:ok, session, [%SessionStopped{session_id: session.id, user_id: scope.user.id}]}
    else
      reason ->
        Logger.error("Cannot stop listening session due to: #{inspect(reason)}")
        {:error, []}
    end
  end

  def handle(%StopListeningSession{source: :playlist, session_id: session_id, scope: scope}) do
    with session <- ListeningSession.get(session_id),
         {:ok, _} <- Report.generate(session),
         {:ok, _} <- Apis.twitch().unsubscribe(scope, "channel.chat.message"),
         message <-
           PremiereEcoute.Gettext.t(scope, fn -> gettext("The premiere of %{name} is over", name: session.playlist.title) end),
         :ok <- Apis.twitch().send_chat_message(scope, message),
         {:ok, session} <- ListeningSession.stop(session) do
      {:ok, devices} = Apis.spotify().devices(scope)
      is_active = Enum.any?(devices, fn device -> device["is_active"] end)
      if is_active, do: Apis.spotify().pause_playback(scope)
      {:ok, session, [%SessionStopped{session_id: session.id, user_id: scope.user.id}]}
    else
      reason ->
        Logger.error("Cannot stop listening session due to: #{inspect(reason)}")
        {:error, []}
    end
  end

  def handle(%PrepareListeningSession{
        source: :free,
        user_id: user_id,
        name: name,
        vote_options: vote_options,
        vote_mode: vote_mode,
        autostart: autostart
      }) do
    resolved_options = vote_options || ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]

    case ListeningSession.create(%{
           user_id: user_id,
           source: :free,
           name: name || "Free session",
           vote_mode: vote_mode || :chat,
           vote_options: resolved_options,
           options: %{"votes" => 0, "scores" => 0, "next_track" => 0, "autostart" => autostart}
         }) do
      {:ok, session} ->
        {:ok, session,
         [
           %SessionPrepared{
             source: :free,
             session_id: session.id,
             user_id: session.user_id
           }
         ]}

      {:error, reason} ->
        Logger.error("Cannot prepare free listening session due to: #{inspect(reason)}")
        {:error, [%SessionNotPrepared{user_id: user_id}]}
    end
  end

  def handle(%StartListeningSession{source: :free, session_id: session_id, scope: scope}) do
    with {:ok, devices} <- Apis.spotify().devices(scope),
         true <- Enum.any?(devices, fn device -> device["is_active"] end),
         {:ok, _} <- Apis.twitch().resubscribe(scope, "channel.chat.message"),
         session <- ListeningSession.get(session_id),
         {:ok, _} <- Report.generate(session),
         {:ok, session} <- ListeningSession.start(session) do
      {:ok, session, [%SessionStarted{source: :free, session_id: session.id, user_id: scope.user.id}]}
    else
      false ->
        {:error, "No Spotify active device detected"}

      {:error, :active_session_exists} ->
        {:error, "You already have an active listening session"}

      reason ->
        Logger.error("Cannot start free listening session due to: #{inspect(reason)}")
        {:error, []}
    end
  end

  def handle(%CaptureCurrentTrackListeningSession{session_id: session_id, scope: scope}) do
    with {:ok, %{"item" => item, "is_playing" => true}} <- Apis.cache(:spotify).get_playback_state(scope, %{}),
         {:ok, single} <- Apis.spotify().get_single(item["id"]),
         {:ok, single} <- Single.create_if_not_exists(single),
         session <- ListeningSession.get(session_id),
         {:ok, session} <- set_single_id(session, single.id) do
      {:ok, session,
       [
         %TrackCaptured{
           session_id: session.id,
           user_id: scope.user.id,
           single_id: single.id,
           track_name: single.name,
           artist: single.artist
         }
       ]}
    else
      {:ok, _no_playback} ->
        {:error, :no_active_playback}

      {:error, reason} ->
        Logger.error("Cannot capture track due to: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle(%OpenVoteWindowListeningSession{session_id: session_id, scope: scope}) do
    session = ListeningSession.get(session_id)

    cond do
      session.status != :active ->
        {:error, :session_not_active}

      is_nil(session.single_id) ->
        {:error, :no_captured_track}

      true ->
        {:ok, session,
         [
           %VoteWindowOpened{
             session_id: session.id,
             user_id: scope.user.id,
             track_id: session.single_id,
             vote_mode: session.vote_mode
           }
         ]}
    end
  end

  def handle(%CloseVoteWindowListeningSession{session_id: session_id, scope: scope}) do
    session = ListeningSession.get(session_id)

    {:ok, session,
     [
       %VoteWindowClosed{
         session_id: session.id,
         user_id: scope.user.id,
         vote_mode: session.vote_mode
       }
     ]}
  end

  def handle(%StopListeningSession{source: :free, session_id: session_id, scope: scope}) do
    with session <- ListeningSession.get(session_id),
         {:ok, _} <- Report.generate(session),
         {:ok, _} <- Apis.twitch().unsubscribe(scope, "channel.chat.message"),
         message <-
           PremiereEcoute.Gettext.t(scope, fn ->
             gettext("The free session %{name} is over", name: session.name || "Free session")
           end),
         :ok <- Apis.twitch().send_chat_message(scope, message),
         {:ok, session} <- ListeningSession.stop(session) do
      {:ok, devices} = Apis.spotify().devices(scope)
      is_active = Enum.any?(devices, fn device -> device["is_active"] end)
      if is_active, do: Apis.spotify().pause_playback(scope)
      {:ok, session, [%SessionStopped{session_id: session.id, user_id: scope.user.id}]}
    else
      reason ->
        Logger.error("Cannot stop free listening session due to: #{inspect(reason)}")
        {:error, []}
    end
  end

  defp get_or_create_playlist(playlist) do
    case Playlist.get_by(playlist_id: playlist.playlist_id, provider: playlist.provider) do
      nil -> Playlist.create(%{playlist | url: Discography.url(playlist, playlist.provider)})
      existing_playlist -> {:ok, existing_playlist}
    end
  end

  defp maybe_start_playback(true, _scope, _single), do: {:ok, :resumed}
  defp maybe_start_playback(false, scope, single), do: Apis.spotify().start_resume_playback(scope, single)

  defp set_single_id(session, single_id) do
    session
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_change(:single_id, single_id)
    |> PremiereEcoute.Repo.update()
    |> case do
      {:ok, s} -> {:ok, ListeningSession.get(s.id)}
      err -> err
    end
  end
end
