defmodule PremiereEcoute.Sessions.ListeningSession.EventHandler do
  @moduledoc """
  Event handler for listening session events.

  Reacts to session lifecycle events by creating track markers, scheduling worker jobs for vote windows and promo messages, and broadcasting session state changes via PubSub.
  """

  use PremiereEcouteCore.EventBus.Handler

  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Events.NextTrackStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.PreviousTrackStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStopped
  alias PremiereEcoute.Sessions.ListeningSessionWorker

  event(PremiereEcoute.Sessions.ListeningSession.Events.SessionPrepared)
  event(PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted)
  event(PremiereEcoute.Sessions.ListeningSession.Events.SessionStopped)
  event(PremiereEcoute.Sessions.ListeningSession.Events.NextTrackStarted)
  event(PremiereEcoute.Sessions.ListeningSession.Events.PreviousTrackStarted)

  @cooldown Application.compile_env(:premiere_ecoute, PremiereEcoute.Sessions)[:vote_cooldown]

  @impl true
  def dispatch(%SessionStarted{source: :album, session_id: session_id, user_id: user_id}) do
    session = ListeningSession.get(session_id)
    ListeningSession.add_track_marker(session)
    ListeningSessionWorker.in_minutes(%{action: "send_promo_message", user_id: user_id}, 1)
    PremiereEcoute.PubSub.broadcast("playback:#{user_id}", {:session_started, session_id})
    :ok
  end

  def dispatch(%SessionStarted{source: :playlist, session_id: session_id, user_id: user_id}) do
    session = ListeningSession.get(session_id)
    ListeningSession.add_track_marker(session)
    ListeningSessionWorker.in_seconds(%{action: "close", session_id: session_id, user_id: user_id}, 0)
    ListeningSessionWorker.in_seconds(%{action: "open_playlist", session_id: session_id, user_id: user_id}, @cooldown)
    ListeningSessionWorker.in_seconds(%{action: "send_promo_message", user_id: user_id}, 25)
    :ok
  end

  def dispatch(%NextTrackStarted{source: :album, session_id: session_id, user_id: user_id, track: track}) do
    session = ListeningSession.get(session_id)
    ListeningSession.add_track_marker(session)
    ListeningSessionWorker.in_seconds(%{action: "close", session_id: session_id, user_id: user_id}, 0)
    open_delay = if track.duration_ms <= @cooldown * 2 * 1000, do: 5, else: @cooldown
    ListeningSessionWorker.in_seconds(%{action: "open_album", session_id: session_id, user_id: user_id}, open_delay)
    PremiereEcoute.PubSub.broadcast("session:#{session_id}", {:next_track, track})
    :ok
  end

  def dispatch(%NextTrackStarted{source: :playlist, session_id: session_id, user_id: user_id, track: track}) do
    session = ListeningSession.get(session_id)
    ListeningSession.add_track_marker(session)
    ListeningSessionWorker.in_seconds(%{action: "close", session_id: session_id, user_id: user_id}, 0)
    open_delay = if track.duration_ms <= @cooldown * 2 * 1000, do: 5, else: @cooldown
    ListeningSessionWorker.in_seconds(%{action: "open_playlist", session_id: session_id, user_id: user_id}, open_delay)
    :ok
  end

  def dispatch(%PreviousTrackStarted{session_id: session_id, user_id: user_id, track: track}) do
    session = ListeningSession.get(session_id)
    ListeningSession.add_track_marker(session)
    ListeningSessionWorker.in_seconds(%{action: "close", session_id: session_id, user_id: user_id}, 0)
    open_delay = if track.duration_ms <= @cooldown * 2 * 1000, do: 5, else: @cooldown
    ListeningSessionWorker.in_seconds(%{action: "open_album", session_id: session_id, user_id: user_id}, open_delay)
    PremiereEcoute.PubSub.broadcast("session:#{session_id}", {:previous_track, track})
    :ok
  end

  def dispatch(%SessionStopped{session_id: session_id, user_id: user_id}) do
    ListeningSessionWorker.in_seconds(%{action: "send_promo_message", user_id: user_id}, 10)
    PremiereEcoute.PubSub.broadcast("session:#{session_id}", :stop)
    PremiereEcoute.PubSub.broadcast("playback:#{user_id}", {:session_stopped, session_id})
    :ok
  end

  def dispatch(_), do: :ok
end
