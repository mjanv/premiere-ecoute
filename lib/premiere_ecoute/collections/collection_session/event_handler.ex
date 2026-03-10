defmodule PremiereEcoute.Collections.CollectionSession.EventHandler do
  @moduledoc """
  Event handler for collection session events.

  Reacts to session events by broadcasting state changes via PubSub and scheduling
  Oban workers for vote window timers.
  """

  use PremiereEcouteCore.EventBus.Handler

  alias PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionCompleted
  alias PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionPrepared
  alias PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionStarted
  alias PremiereEcoute.Collections.CollectionSession.Events.TrackDecided
  alias PremiereEcoute.Collections.CollectionSession.Events.VoteWindowClosed
  alias PremiereEcoute.Collections.CollectionSession.Events.VoteWindowOpened
  alias PremiereEcoute.Collections.CollectionSessionWorker

  event(CollectionSessionPrepared)
  event(CollectionSessionStarted)
  event(TrackDecided)
  event(VoteWindowOpened)
  event(VoteWindowClosed)
  event(CollectionSessionCompleted)

  @impl true
  def dispatch(%CollectionSessionPrepared{}), do: :ok

  @impl true
  def dispatch(%CollectionSessionStarted{session_id: session_id, user_id: user_id}) do
    PremiereEcoute.PubSub.broadcast("collection:#{session_id}", :session_started)
    PremiereEcoute.PubSub.broadcast("playback:#{user_id}", {:collection_started, session_id})
    :ok
  end

  @impl true
  def dispatch(%TrackDecided{session_id: session_id, track_id: track_id, decision: decision}) do
    PremiereEcoute.PubSub.broadcast("collection:#{session_id}", {:track_decided, track_id, decision})
    :ok
  end

  @impl true
  def dispatch(%VoteWindowOpened{
        session_id: session_id,
        user_id: user_id,
        track_id: track_id,
        vote_duration: vote_duration
      }) do
    # Schedule auto-close after vote_duration seconds
    CollectionSessionWorker.in_seconds(
      %{action: "close_vote", session_id: session_id, user_id: user_id, track_id: track_id},
      vote_duration
    )

    PremiereEcoute.PubSub.broadcast("collection:#{session_id}", :vote_open)
    :ok
  end

  @impl true
  def dispatch(%VoteWindowClosed{session_id: session_id, track_id: track_id}) do
    PremiereEcoute.PubSub.broadcast("collection:#{session_id}", {:vote_closed, track_id})
    :ok
  end

  @impl true
  def dispatch(%CollectionSessionCompleted{session_id: session_id, user_id: user_id, kept_count: kept_count}) do
    PremiereEcoute.PubSub.broadcast("collection:#{session_id}", {:session_completed, kept_count})
    PremiereEcoute.PubSub.broadcast("playback:#{user_id}", {:collection_completed, session_id})
    :ok
  end
end
