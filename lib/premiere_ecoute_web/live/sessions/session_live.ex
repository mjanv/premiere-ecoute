defmodule PremiereEcouteWeb.Sessions.SessionLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Apis.SpotifyApi.Player
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession
  alias PremiereEcoute.Sessions.Scores.Report
  alias PremiereEcoute.Sessions.Scores.Vote

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

        # AIDEV-NOTE: Get current user for Spotify integration
        current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

        {:ok,
         socket
         |> assign(:listening_session, listening_session)
         |> assign(:player_state, nil)
         |> assign(:session_id, session_id)
         |> assign(:current_user, current_user)
         |> assign(:show, %{votes: true, scores: true})
         |> assign(:user_current_rating, nil)
         |> assign(:report, nil)
         |> assign_async(:report, fn ->
           {:ok, %{report: Report.get_by(session_id: String.to_integer(session_id))}}
         end)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "start_session",
        _params,
        %{assigns: %{listening_session: session, current_user: user, current_scope: scope}} =
          socket
      ) do
    %StartListeningSession{session_id: session.id, scope: scope}
    |> PremiereEcoute.apply()
    |> case do
      {:ok, updated_session, _} ->
        socket =
          case start_spotify_playback(user, updated_session) do
            {:ok, _} ->
              socket |> put_flash(:info, "Session started and Spotify playback began!")

            {:error, reason} ->
              socket |> put_flash(:warning, "Session started but Spotify failed: #{reason}")
          end

        {:noreply, assign(socket, :listening_session, updated_session)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Cannot start session")}
    end
  end

  def handle_event(
        "stop_session",
        _params,
        %{assigns: %{listening_session: session, current_scope: scope}} = socket
      ) do
    %StopListeningSession{session_id: session.id, scope: scope}
    |> PremiereEcoute.apply()
    |> case do
      {:ok, session, _} ->
        {:noreply, assign(socket, :listening_session, session)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Cannot stop session")}
    end
  end

  @impl true
  def handle_event("toggle", %{"flag" => flag}, %{assigns: assigns} = socket) do
    {:noreply,
     assign(socket, :show, Map.update!(assigns.show, String.to_atom(flag), fn v -> !v end))}
  end

  @impl true
  def handle_event("open_overlay", _params, socket) do
    overlay_url = "#{socket.host_uri}/session/#{socket.assigns.listening_session.id}/overlay"
    {:noreply, push_event(socket, "open_url", %{url: overlay_url})}
  end

  @impl true
  def handle_event("copy_overlay_url", _params, socket) do
    overlay_url = "#{socket.host_uri}/session/#{socket.assigns.listening_session.id}/overlay"

    {:noreply,
     socket
     |> push_event("copy_to_clipboard", %{text: overlay_url})
     |> put_flash(:info, "Overlay URL copied to clipboard!")}
  end

  # AIDEV-NOTE: Spotify player events are now handled by the LiveComponent

  @impl true
  def handle_event("vote_track", %{"track_id" => track_id, "rating" => rating}, socket) do
    case Integer.parse(track_id) do
      {int_track_id, ""} ->
        case Integer.parse(rating) do
          {int_rating, ""} when int_rating >= 1 and int_rating <= 10 ->
            # AIDEV-NOTE: Create streamer vote and save to database
            case create_streamer_vote(socket, int_track_id, int_rating) do
              {:ok, _vote} ->
                socket = assign(socket, :user_current_rating, int_rating)
                {:noreply, put_flash(socket, :info, "Rated track #{int_rating}/10")}

              {:error, reason} ->
                Logger.error("Failed to create streamer vote: #{inspect(reason)}")
                {:noreply, put_flash(socket, :error, "Failed to save rating")}
            end

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

  @impl true
  def handle_info({:session_updated, session}, socket) do
    # AIDEV-NOTE: Handle session updates from Spotify player component
    socket = assign(socket, :listening_session, session)
    socket = assign(socket, :user_current_rating, nil)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:refreshh, socket) do
    socket = PremiereEcouteWeb.Sessions.Components.SpotifyPlayer.refresh_state(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_info(%Vote{} = _vote, socket) do
    session_id = socket.assigns.session_id

    {:noreply,
     socket
     |> assign_async(:report, fn ->
       {:ok, %{report: Report.get_by(session_id: String.to_integer(session_id))}}
     end)}
  end

  @impl true
  def handle_info(event, socket) do
    {:noreply, put_flash(socket, :info, "Received #{inspect(event)}")}
  end

  @impl true
  def handle_async(:report, {:ok, %{report: report}}, socket) do
    {:noreply, assign(socket, :report, report)}
  end

  @impl true
  def handle_async(:report, {:exit, reason}, socket) do
    Logger.error("Failed to load session report: #{inspect(reason)}")
    {:noreply, socket}
  end

  def format_duration(nil), do: "--:--"

  def format_duration(duration_ms) when is_integer(duration_ms) do
    total_seconds = div(duration_ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
  end

  def session_status_class(:preparing),
    do: "bg-gradient-to-r from-amber-500 to-orange-500 text-white shadow-md"

  def session_status_class(:active),
    do: "bg-gradient-to-r from-emerald-500 to-teal-600 text-white shadow-md"

  def session_status_class(:stopped),
    do: "bg-gradient-to-r from-slate-500 to-gray-600 text-white shadow-md"

  # AIDEV-NOTE: Helper functions to extract data from Report struct for template use
  def track_score(_track_id, nil), do: 0.0

  def track_score(track_id, report) do
    case Enum.find(report.track_summaries, &(&1["track_id"] == track_id)) do
      nil -> 0.0
      track_summary -> Float.round(track_summary["viewer_score"] || 0.0, 1)
    end
  end

  def track_votes_count(_track_id, nil), do: 0

  def track_votes_count(track_id, report) do
    case Enum.find(report.track_summaries, &(&1["track_id"] == track_id)) do
      nil -> 0
      track_summary -> track_summary["unique_votes"] || 0
    end
  end

  def session_average_score(nil), do: 0.0

  def session_average_score(report) do
    case report.session_summary do
      %{"viewer_score" => score} when is_number(score) -> Float.round(score, 1)
      _ -> 0.0
    end
  end

  def session_total_votes(nil), do: 0
  def session_total_votes(report), do: report.unique_votes || 0

  def session_unique_voters(nil), do: 0
  def session_unique_voters(report), do: report.unique_voters || 0

  def session_tracks_rated(nil), do: 0

  def session_tracks_rated(report) do
    case report.session_summary do
      %{"tracks_rated" => count} when is_integer(count) -> count
      _ -> 0
    end
  end

  def session_streamer_score(nil), do: 0.0

  def session_streamer_score(report) do
    case report.session_summary do
      %{"streamer_score" => score} when is_number(score) -> Float.round(score, 1)
      _ -> 0.0
    end
  end

  def track_streamer_score(_track_id, nil), do: 0.0

  def track_streamer_score(track_id, report) do
    case Enum.find(report.track_summaries, &(&1["track_id"] == track_id)) do
      nil -> 0.0
      track_summary -> Float.round(track_summary["streamer_score"] || 0.0, 1)
    end
  end

  # AIDEV-NOTE: Get vote distribution histogram data for a specific track from raw votes and polls
  def track_vote_distribution(_track_id, nil), do: for(rating <- 1..10, do: {rating, 0})

  def track_vote_distribution(track_id, report) do
    # Calculate distribution from individual votes
    individual_distribution =
      report.votes
      |> Enum.filter(&(&1.track_id == track_id))
      |> Enum.group_by(& &1.value)
      |> Map.new(fn {value, votes} -> {value, length(votes)} end)

    # Calculate distribution from poll votes
    poll_distribution =
      report.polls
      |> Enum.filter(&(&1.track_id == track_id))
      |> Enum.reduce(%{}, fn poll, acc ->
        poll.votes
        |> Enum.reduce(acc, fn {rating_str, count}, inner_acc ->
          rating = String.to_integer(rating_str)
          Map.update(inner_acc, rating, count, &(&1 + count))
        end)
      end)

    # Combine both distributions and ensure all ratings 1-10 are present
    for rating <- 1..10 do
      individual_count = Map.get(individual_distribution, rating, 0)
      poll_count = Map.get(poll_distribution, rating, 0)
      total_count = individual_count + poll_count
      {rating, total_count}
    end
  end

  # AIDEV-NOTE: Get the maximum vote count for highlighting in histogram
  def track_max_votes(_track_id, nil), do: 0

  def track_max_votes(track_id, report) do
    track_vote_distribution(track_id, report)
    |> Enum.map(&elem(&1, 1))
    |> Enum.max(fn -> 0 end)
  end

  # AIDEV-NOTE: Create and save streamer vote, then broadcast for UI updates
  defp create_streamer_vote(socket, track_id, rating) do
    session_id = String.to_integer(socket.assigns.session_id)
    current_scope = socket.assigns.current_scope

    case current_scope do
      %{user: %{id: user_id}} when not is_nil(user_id) ->
        vote_attrs = %Vote{
          viewer_id: to_string(user_id),
          session_id: session_id,
          track_id: track_id,
          value: rating,
          is_streamer: true
        }

        case Vote.create(vote_attrs) do
          {:ok, vote} ->
            # Broadcast vote_cast event for real-time updates
            Phoenix.PubSub.broadcast(
              PremiereEcoute.PubSub,
              "session:#{session_id}",
              {:vote_cast, vote}
            )

            # Regenerate report with new vote data
            listening_session = ListeningSession.get(session_id)
            Report.generate(listening_session)

            {:ok, vote}

          error ->
            error
        end

      _ ->
        {:error, "User not authenticated"}
    end
  end

  defp start_spotify_playback(user, session) do
    case user do
      %{spotify_access_token: access_token} when not is_nil(access_token) ->
        # AIDEV-NOTE: Get the current track from the session
        case get_current_track_uri(session) do
          {:ok, track_uri} ->
            Logger.info("Starting Spotify playback for track: #{track_uri}")
            Player.start_playback(access_token, uris: [track_uri])

          {:error, reason} ->
            Logger.warning("Could not get track URI: #{reason}")
            # Try to start playback without specific track
            Player.start_playback(access_token)
        end

      _ ->
        {:error, "No Spotify connection. Connect Spotify in your account settings."}
    end
  end

  defp get_current_track_uri(session) do
    # AIDEV-NOTE: Get the current track from the session and build Spotify URI
    case session.current_track do
      nil ->
        {:error, "No current track"}

      track when is_map(track) and not is_nil(track.spotify_id) ->
        {:ok, "spotify:track:#{track.spotify_id}"}

      _ ->
        {:error, "Track has no Spotify ID"}
    end
  end
end
