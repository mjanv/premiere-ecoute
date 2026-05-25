defmodule PremiereEcoute.Collections.CollectionSession.EventHandler do
  @moduledoc """
  Event handler for collection session events.

  Reacts to session events by broadcasting state changes via PubSub and scheduling
  Oban workers for vote window timers.
  """

  use PremiereEcouteCore.EventBus.Handler

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Collections.CollectionSession
  alias PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionCompleted
  alias PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionPrepared
  alias PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionStarted
  alias PremiereEcoute.Collections.CollectionSession.Events.TrackDecided
  alias PremiereEcoute.Collections.CollectionSession.Events.VoteWindowClosed
  alias PremiereEcoute.Collections.CollectionSession.Events.VoteWindowOpened
  alias PremiereEcoute.Collections.CollectionSessionWorker
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Workers.EnrichDiscographyWorker

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

    session = CollectionSession.get(session_id)

    if minutes = session.options["duel_reminder_minutes"] do
      CollectionSessionWorker.in_minutes(
        %{"action" => "duel_reminder", "session_id" => session_id},
        minutes
      )
    end

    :ok
  end

  @impl true
  def dispatch(%TrackDecided{session_id: session_id, track_id: track_id, decision: decision}) do
    PremiereEcoute.PubSub.broadcast("collection:#{session_id}", {:track_decided, track_id, decision})
    maybe_schedule_enrichment(decision, track_id)
    :ok
  end

  @impl true
  def dispatch(%VoteWindowOpened{session_id: session_id}) do
    PremiereEcoute.PubSub.broadcast("collection:#{session_id}", :vote_open)
    :ok
  end

  @impl true
  def dispatch(%VoteWindowClosed{session_id: session_id, track_id: track_id}) do
    PremiereEcoute.PubSub.broadcast("collection:#{session_id}", {:vote_closed, track_id})
    :ok
  end

  defp maybe_schedule_enrichment(:kept, track_id) do
    with nil <- Album.Track.find_by_provider(track_id, :spotify),
         {:ok, %Album.Track{artist_spotify_id: id}} when is_binary(id) <- Apis.spotify().get_track(track_id) do
      EnrichDiscographyWorker.now(%{"spotify_id" => id})
    end
  end

  defp maybe_schedule_enrichment(_decision, _track_id), do: :ok

  @impl true
  def dispatch(%CollectionSessionCompleted{session_id: session_id, kept_count: kept_count}) do
    PremiereEcoute.PubSub.broadcast("collection:#{session_id}", {:session_completed, kept_count})
    CollectionSessionWorker.cancel_duel_reminders(session_id)
    :ok
  end
end
