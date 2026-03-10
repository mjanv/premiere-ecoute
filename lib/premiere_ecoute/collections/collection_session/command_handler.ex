defmodule PremiereEcoute.Collections.CollectionSession.CommandHandler do
  @moduledoc """
  Command handler for collection session commands.

  Handles session lifecycle (prepare/start/complete), track decisions, and vote window
  management. Coordinates between the Spotify API, cache, and session state.
  """

  use PremiereEcouteCore.CommandBus.Handler

  require Logger

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Collections.CollectionDecision
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
        destination_playlist_id: dest_id,
        rule: rule,
        selection_mode: mode,
        vote_duration: vote_duration
      }) do
    user_id = scope.user.id

    case CollectionSession.create(%{
           user_id: user_id,
           origin_playlist_id: origin_id,
           destination_playlist_id: dest_id,
           rule: rule,
           selection_mode: mode,
           vote_duration: vote_duration
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

    with {:ok, playlist} <- Apis.provider(session.origin_playlist.provider).get_playlist(session.origin_playlist.playlist_id),
         tracks <- maybe_shuffle(playlist.tracks, session.rule),
         {:ok, _} <- Cache.put(:collections, session_id, %{tracks: tracks, vote_counts: %{}}),
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
        track_name: track_name,
        artist: artist,
        position: position,
        decision: decision,
        votes_a: votes_a,
        votes_b: votes_b,
        duel_track_id: duel_track_id,
        duel_track_name: duel_track_name,
        duel_artist: duel_artist,
        duel_position: duel_position
      }) do
    session = CollectionSession.get(session_id)
    step = if duel_track_id, do: 2, else: 1

    with {:ok, _decision} <-
           CollectionDecision.decide(session_id, %{
             track_id: track_id,
             track_name: track_name,
             artist: artist,
             position: position,
             decision: decision,
             votes_a: votes_a || 0,
             votes_b: votes_b || 0,
             duel_track_id: duel_track_id
           }),
         :ok <- maybe_decide_duel_loser(session_id, duel_track_id, duel_track_name, duel_artist, duel_position),
         {:ok, session} <- CollectionSession.advance(session, step) do
      {:ok, session,
       [
         %TrackDecided{
           session_id: session_id,
           user_id: scope.user.id,
           track_id: track_id,
           decision: decision
         }
       ]}
    else
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
        selection_mode: round_mode,
        vote_duration: round_duration
      }) do
    session = CollectionSession.get(session_id)

    # AIDEV-NOTE: per-round mode/duration override session defaults when provided
    mode = round_mode || session.selection_mode
    duration = round_duration || session.vote_duration

    # AIDEV-NOTE: cache entry stores current track ids so MessagePipeline can route votes
    with {:ok, cached} <- Cache.get(:collections, session_id),
         {:ok, _} <-
           Cache.put(
             :collections,
             session_id,
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

    with {:ok, cached} <- Cache.get(:collections, session_id),
         track_id <- Map.get(cached, :active_track_id),
         {:ok, _} <-
           Cache.put(:collections, session_id, Map.drop(cached, [:active_track_id, :duel_track_id, :votes_a, :votes_b])) do
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
    kept = CollectionDecision.kept_for_session(session_id)
    rejected = if remove_rejected, do: CollectionDecision.rejected_for_session(session_id), else: []
    to_remove = if(remove_kept, do: kept, else: []) ++ rejected

    with {:ok, _} <- sync_to_spotify(scope, session, kept),
         {:ok, _} <- remove_from_origin(scope, session, to_remove),
         {:ok, _} <- Cache.del(:collections, session_id),
         {:ok, session} <- CollectionSession.complete(session) do
      {:ok, session,
       [
         %CollectionSessionCompleted{
           session_id: session_id,
           user_id: scope.user.id,
           kept_count: length(kept)
         }
       ]}
    else
      {:error, reason} ->
        Logger.error("Cannot complete collection session #{session_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp maybe_decide_duel_loser(_session_id, nil, _name, _artist, _position), do: :ok
  defp maybe_decide_duel_loser(_session_id, _track_id, nil, _artist, _position), do: :ok

  defp maybe_decide_duel_loser(session_id, track_id, track_name, artist, position) do
    case CollectionDecision.decide(session_id, %{
           track_id: track_id,
           track_name: track_name,
           artist: artist,
           position: position,
           decision: :rejected,
           votes_a: 0,
           votes_b: 0,
           duel_track_id: nil
         }) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_shuffle(tracks, :random), do: Enum.shuffle(tracks)
  defp maybe_shuffle(tracks, :ordered), do: tracks

  defp remove_from_origin(_scope, _session, []), do: {:ok, :nothing_to_remove}

  defp remove_from_origin(scope, session, decisions) do
    playlist_id = session.origin_playlist.playlist_id
    tracks = Enum.map(decisions, &%Track{provider: :spotify, track_id: &1.track_id})
    Apis.spotify().remove_playlist_items(scope, playlist_id, tracks)
  end

  defp sync_to_spotify(_scope, _session, []), do: {:ok, :nothing_to_sync}

  defp sync_to_spotify(scope, session, kept) do
    playlist_id = session.destination_playlist.playlist_id
    # AIDEV-NOTE: convert CollectionDecision records to Playlist.Track structs for the Spotify API
    tracks = Enum.map(kept, &%Track{provider: :spotify, track_id: &1.track_id})
    Apis.spotify().add_items_to_playlist(scope, playlist_id, tracks)
  end
end
