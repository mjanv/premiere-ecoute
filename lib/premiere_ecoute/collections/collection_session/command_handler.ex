defmodule PremiereEcoute.Collections.CollectionSession.CommandHandler do
  @moduledoc """
  Command handler for collection session commands.

  Handles session lifecycle (prepare/start/complete), track decisions, and vote window
  management. Coordinates between the Spotify API, cache, and session state.
  """

  use PremiereEcouteCore.CommandBus.Handler

  require Logger

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Collections.CollectionSession
  alias PremiereEcoute.Collections.CollectionSession.Commands.CloseVoteWindow
  alias PremiereEcoute.Collections.CollectionSession.Commands.CompleteCollectionSession
  alias PremiereEcoute.Collections.CollectionSession.Commands.DecideTrack
  alias PremiereEcoute.Collections.CollectionSession.Commands.OpenVoteWindow
  alias PremiereEcoute.Collections.CollectionSession.Commands.PrepareCollectionSession
  alias PremiereEcoute.Collections.CollectionSession.Commands.StartCollectionSession
  alias PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionCompleted
  alias PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionPrepared
  alias PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionStarted
  alias PremiereEcoute.Collections.CollectionSession.Events.TrackDecided
  alias PremiereEcoute.Collections.CollectionSession.Events.VoteWindowClosed
  alias PremiereEcoute.Collections.CollectionSession.Events.VoteWindowOpened
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcouteCore.Cache

  command(PrepareCollectionSession)
  command(StartCollectionSession)
  command(DecideTrack)
  command(OpenVoteWindow)
  command(CloseVoteWindow)
  command(CompleteCollectionSession)

  @doc false
  def handle(%PrepareCollectionSession{
        scope: scope,
        origin_playlist_id: origin_id,
        destination_playlist_id: dest_id
      }) do
    user_id = scope.user.id

    case CollectionSession.create(%{
           user_id: user_id,
           origin_playlist_id: origin_id,
           destination_playlist_id: dest_id
         }) do
      {:ok, session} ->
        {:ok, session,
         [
           %CollectionSessionPrepared{
             session_id: session.id,
             user_id: user_id
           }
         ]}

      {:error, reason} ->
        Logger.error("Cannot prepare collection session: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc false
  def handle(%StartCollectionSession{session_id: session_id, scope: scope}) do
    session = CollectionSession.get(session_id)
    # AIDEV-NOTE: cache is keyed by broadcaster_id (Twitch user_id) so MessagePipeline can look
    # it up from incoming MessageSent events. session_id is stored inside for the pipeline to use.
    broadcaster_id = scope.user.twitch.user_id

    with {:ok, playlist} <- Apis.provider(session.origin_playlist.provider).get_playlist(session.origin_playlist.playlist_id),
         {:ok, _} <- Cache.put(:collections, broadcaster_id, %{session_id: session_id, tracks: playlist.tracks}),
         {:ok, _} <- Apis.twitch().resubscribe(scope, "channel.chat.message"),
         {:ok, session} <- CollectionSession.start(session) do
      {:ok, session,
       [
         %CollectionSessionStarted{
           session_id: session.id,
           user_id: scope.user.id
         }
       ]}
    else
      {:error, reason} ->
        Logger.error("Cannot start collection session #{session_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc false
  def handle(%DecideTrack{
        session_id: session_id,
        scope: scope,
        track_id: track_id,
        decision: decision,
        duel_track_id: duel_track_id
      }) do
    session = CollectionSession.get(session_id)
    # AIDEV-NOTE: duel advances by 2; winner goes to :kept, loser to :rejected in one update
    step = if duel_track_id, do: 2, else: 1

    attrs =
      if duel_track_id do
        winner_id = if decision == :kept, do: track_id, else: duel_track_id
        loser_id = if decision == :kept, do: duel_track_id, else: track_id

        %{
          kept: session.kept ++ [winner_id],
          rejected: session.rejected ++ [loser_id],
          current_index: session.current_index + step
        }
      else
        %{
          decision => Map.get(session, decision, []) ++ [track_id],
          current_index: session.current_index + step
        }
      end

    case CollectionSession.update(session, attrs) do
      {:ok, session} ->
        {:ok, session,
         [
           %TrackDecided{
             session_id: session_id,
             user_id: scope.user.id,
             track_id: track_id,
             decision: if(duel_track_id && decision != :kept, do: :kept, else: decision)
           }
         ]}

      {:error, reason} ->
        Logger.error("Cannot record decision for session #{session_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc false
  def handle(%OpenVoteWindow{
        session_id: session_id,
        scope: scope,
        track_id: track_id,
        duel_track_id: duel_track_id,
        selection_mode: mode,
        vote_duration: duration
      }) do
    session = CollectionSession.get(session_id)
    broadcaster_id = scope.user.twitch.user_id

    # AIDEV-NOTE: cache entry stores current track ids so MessagePipeline can route votes
    with {:ok, cached} <- Cache.get(:collections, broadcaster_id),
         {:ok, _} <-
           Cache.put(
             :collections,
             broadcaster_id,
             Map.merge(cached, %{
               active_track_id: track_id,
               duel_track_id: duel_track_id,
               votes_a: 0,
               votes_b: 0
             })
           ) do
      {:ok, session,
       [
         %VoteWindowOpened{
           session_id: session_id,
           user_id: scope.user.id,
           track_id: track_id,
           duel_track_id: duel_track_id,
           selection_mode: mode,
           vote_duration: duration
         }
       ]}
    else
      {:error, reason} ->
        Logger.error("Cannot open vote window for session #{session_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc false
  def handle(%CloseVoteWindow{session_id: session_id, scope: scope}) do
    session = CollectionSession.get(session_id)
    broadcaster_id = scope.user.twitch.user_id

    with {:ok, cached} <- Cache.get(:collections, broadcaster_id),
         track_id <- Map.get(cached, :active_track_id),
         {:ok, _} <-
           Cache.put(:collections, broadcaster_id, Map.drop(cached, [:active_track_id, :duel_track_id, :votes_a, :votes_b])) do
      {:ok, session,
       [
         %VoteWindowClosed{
           session_id: session_id,
           user_id: scope.user.id,
           track_id: track_id
         }
       ]}
    else
      {:error, reason} ->
        Logger.error("Cannot close vote window for session #{session_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc false
  def handle(%CompleteCollectionSession{
        session_id: session_id,
        scope: scope,
        remove_kept: remove_kept,
        remove_rejected: remove_rejected
      }) do
    session = CollectionSession.get(session_id)
    to_remove = if(remove_kept, do: session.kept, else: []) ++ if remove_rejected, do: session.rejected, else: []

    broadcaster_id = scope.user.twitch.user_id

    with {:ok, _} <- sync_to_spotify(scope, session),
         {:ok, _} <- remove_from_origin(scope, session, to_remove),
         {:ok, _} <- Apis.twitch().unsubscribe(scope, "channel.chat.message"),
         {:ok, _} <- Cache.del(:collections, broadcaster_id),
         {:ok, session} <- CollectionSession.complete(session) do
      {:ok, session,
       [
         %CollectionSessionCompleted{
           session_id: session_id,
           user_id: scope.user.id,
           kept_count: length(session.kept)
         }
       ]}
    else
      {:error, reason} ->
        Logger.error("Cannot complete collection session #{session_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp remove_from_origin(_scope, _session, []), do: {:ok, :nothing_to_remove}

  defp remove_from_origin(scope, session, track_ids) do
    playlist_id = session.origin_playlist.playlist_id
    tracks = Enum.map(track_ids, &%Track{provider: :spotify, track_id: &1})
    Apis.spotify().remove_playlist_items(scope, playlist_id, tracks)
  end

  defp sync_to_spotify(_scope, %{kept: []}), do: {:ok, :nothing_to_sync}

  defp sync_to_spotify(scope, session) do
    playlist_id = session.destination_playlist.playlist_id
    # AIDEV-NOTE: convert kept track_id list to Track structs for the Spotify API
    tracks = Enum.map(session.kept, &%Track{provider: :spotify, track_id: &1})
    Apis.spotify().add_items_to_playlist(scope, playlist_id, tracks)
  end
end
