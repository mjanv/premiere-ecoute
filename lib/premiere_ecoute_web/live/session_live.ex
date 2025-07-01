defmodule PremiereEcouteWeb.SessionLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession

  @impl true
  def mount(%{"id" => session_id}, _session, socket) do
    listening_session =
      case Integer.parse(session_id) do
        {int_id, ""} -> ListeningSession.get(int_id)
        _ -> nil
      end

    case listening_session do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Session not found")
         |> redirect(to: ~p"/")}

      listening_session ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "session:#{session_id}")
        end

        {:ok,
         socket
         |> assign(:listening_session, listening_session)
         |> assign(:session_id, session_id)
         |> assign(:show_votes, true)
         |> assign(:show_scores, true)
         |> assign(:user_current_rating, nil)
         |> assign_async(:session_data, fn ->
           {:ok, %{session_data: load_session_data(listening_session)}}
         end)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:session_updated, session}, socket) do
    {:noreply, assign(socket, :listening_session, session)}
  end

  @impl true
  def handle_info({:track_changed, track_info}, socket) do
    {:noreply, assign(socket, :current_track, track_info)}
  end

  @impl true
  def handle_info({:votes_updated, votes}, socket) do
    {:noreply, assign(socket, :votes, votes)}
  end

  @impl true
  def handle_info({:scores_updated, scores}, socket) do
    {:noreply, assign(socket, :scores, scores)}
  end

  @impl true
  def handle_event("start_session", _params, %{assigns: %{listening_session: session}} = socket) do
    case ListeningSession.start(session) do
      {:ok, started_session} -> 
        # AIDEV-NOTE: Automatically select first track when starting session
        case ListeningSession.next_track(started_session) do
          {:ok, session_with_track} ->
            Phoenix.PubSub.broadcast(PremiereEcoute.PubSub, "session:#{session.id}", {:track_changed, session_with_track.current_track})
            socket = assign(socket, :listening_session, session_with_track)
            socket = assign(socket, :user_current_rating, nil)
            {:noreply, socket}
          {:error, _} ->
            # If no tracks available, just start without selecting a track
            {:noreply, assign(socket, :listening_session, started_session)}
        end
      {:error, _} -> {:noreply, put_flash(socket, :error, "Cannot start session")}
    end
  end

  def handle_event("end_session", _params, %{assigns: %{listening_session: session}} = socket) do
    case ListeningSession.stop(session) do
      {:ok, session} -> {:noreply, assign(socket, :listening_session, session)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Cannot stop session")}
    end
  end

  @impl true
  def handle_event("toggle_votes", _params, socket) do
    {:noreply, assign(socket, :show_votes, !socket.assigns.show_votes)}
  end

  @impl true
  def handle_event("toggle_scores", _params, socket) do
    {:noreply, assign(socket, :show_scores, !socket.assigns.show_scores)}
  end


  @impl true
  def handle_event("next_track", _params, %{assigns: %{listening_session: session}} = socket) do
    case ListeningSession.next_track(session) do
      {:ok, updated_session} -> 
        # AIDEV-NOTE: Broadcast track change to update UI and notify other subscribers
        Phoenix.PubSub.broadcast(PremiereEcoute.PubSub, "session:#{session.id}", {:track_changed, updated_session.current_track})
        # Clear user rating when track changes
        socket = assign(socket, :listening_session, updated_session)
        socket = assign(socket, :user_current_rating, nil)
        {:noreply, socket}
      {:error, :no_tracks_left} -> 
        {:noreply, put_flash(socket, :info, "Already at the last track")}
      {:error, _reason} -> 
        {:noreply, put_flash(socket, :error, "Failed to go to next track")}
    end
  end

  @impl true
  def handle_event("previous_track", _params, %{assigns: %{listening_session: session}} = socket) do
    case ListeningSession.previous_track(session) do
      {:ok, updated_session} -> 
        # AIDEV-NOTE: Broadcast track change to update UI and notify other subscribers
        Phoenix.PubSub.broadcast(PremiereEcoute.PubSub, "session:#{session.id}", {:track_changed, updated_session.current_track})
        # Clear user rating when track changes
        socket = assign(socket, :listening_session, updated_session)
        socket = assign(socket, :user_current_rating, nil)
        {:noreply, socket}
      {:error, :no_tracks_left} -> 
        {:noreply, put_flash(socket, :info, "Already at the first track")}
      {:error, _reason} -> 
        {:noreply, put_flash(socket, :error, "Failed to go to previous track")}
    end
  end

  @impl true
  def handle_event("vote_track", %{"track_id" => track_id, "rating" => rating}, socket) do
    case Integer.parse(track_id) do
      {_int_track_id, ""} ->
        case Integer.parse(rating) do
          {int_rating, ""} when int_rating >= 1 and int_rating <= 10 ->
            # AIDEV-NOTE: Store user's rating for the track and update UI
            socket = assign(socket, :user_current_rating, int_rating)
            
            # Here you would typically save the vote to the database
            # For now, just update the UI and show confirmation
            {:noreply, put_flash(socket, :info, "Rated track #{int_rating}/10")}
          _ ->
            {:noreply, put_flash(socket, :error, "Invalid rating")}
        end
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid track")}
    end
  end

  @impl true
  def handle_event(event, _params, socket) do
    {:noreply, put_flash(socket, :info, "Received event: #{event}")}
  end

  defp load_session_data(listening_session) do
    with %Album{} = album <- Album.get(listening_session.album_id),
         {:ok, votes} <- Sessions.get_session_votes(listening_session.id),
         {:ok, scores} <- Sessions.get_session_scores(listening_session.id) do
      %{
        album: album,
        tracks: album.tracks || [],
        votes: votes,
        scores: scores,
        current_track: get_current_track(listening_session)
      }
    else
      error ->
        Logger.error("Failed to load session data: #{inspect(error)}")
        %{error: "Failed to load session data"}
    end
  end

  defp get_current_track(listening_session) do
    case Sessions.get_current_playing_track(listening_session.id) do
      {:ok, track} -> track
    end
  end

  def format_duration(nil), do: "--:--"

  def format_duration(duration_ms) when is_integer(duration_ms) do
    total_seconds = div(duration_ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
  end

  def session_status_class(:preparing), do: "bg-yellow-900/30 text-yellow-400"
  def session_status_class(:active), do: "bg-green-900/30 text-green-400"
  def session_status_class(:stopped), do: "bg-gray-700 text-gray-300"

  def track_score(track_id, scores) do
    case Enum.find(scores, &(&1.track_id == track_id)) do
      nil -> 0
      score -> score.average_score || 0
    end
  end

  def track_votes_count(track_id, votes) do
    votes
    |> Enum.filter(&(&1.track_id == track_id))
    |> length()
  end
end
