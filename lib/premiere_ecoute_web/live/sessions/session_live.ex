defmodule PremiereEcouteWeb.Sessions.SessionLive do
  @moduledoc """
  Individual session management LiveView.

  Manages listening session lifecycle with real-time Spotify player integration, vote window controls, track navigation, visibility settings, live statistics with vote trends charts, overlay configuration, and automatic track advancement with scheduled workers.
  """

  use PremiereEcouteWeb, :live_view

  require Logger

  import PremiereEcouteWeb.Sessions.Components.SessionComponents
  import PremiereEcouteWeb.Components.Backgrounds

  alias PremiereEcoute.Apis.PlayerSupervisor
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Presence
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.SkipNextTrackListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession
  alias PremiereEcoute.Sessions.ListeningSessionWorker
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Retrospective.VoteTrends
  alias PremiereEcouteCore.Cache

  @impl true
  def mount(%{"id" => id}, _session, %{assigns: %{current_scope: current_scope}} = socket) do
    with spotify when not is_nil(spotify) <- current_scope && current_scope.user && current_scope.user.spotify,
         listening_session when not is_nil(listening_session) <- ListeningSession.get(id) do
      if connected?(socket) do
        Process.send_after(self(), :refresh, 100)
        {:ok, _} = Presence.join(current_scope.user.id)
        PremiereEcoute.PubSub.subscribe(["playback:#{current_scope.user.id}", "session:#{id}"])
        _ = PlayerSupervisor.start(current_scope.user.id)
      end

      {:ok, cached_session} = Cache.get(:sessions, current_scope.user.twitch.user_id)

      socket
      |> assign(:listening_session, listening_session)
      |> assign(:open_vote, !is_nil(cached_session))
      |> assign(:player_state, nil)
      |> assign(:session_id, id)
      |> assign(:user_current_rating, nil)
      |> assign(:report, nil)
      |> assign(:overlay_score_type, "streamer")
      |> assign(:vote_trends, nil)
      |> assign(:next_track_at, nil)
      |> assign(:show_youtube_modal, false)
      |> assign_async(:report, fn -> {:ok, %{report: Report.get_by(session_id: id)}} end)
      |> assign_async(:vote_trends, fn ->
        {:ok, %{vote_trends: VoteTrends.rolling_average(String.to_integer(id), :minute)}}
      end)
      |> then(fn socket -> {:ok, socket} end)
    else
      _ ->
        socket
        |> put_flash(:error, "Session not found or connect to Spotify")
        |> redirect(to: ~p"/sessions")
        |> then(fn socket -> {:ok, socket} end)
    end
  end

  @impl true
  def terminate(_reason, %{assigns: assigns}) do
    Presence.unjoin(assigns.current_scope.user.id)
    :ok
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, assign(socket, :current_path, URI.parse(url).path || "/")}
  end

  @impl true
  def handle_event(
        "start_session",
        _params,
        %{assigns: %{listening_session: session, current_scope: scope}} = socket
      ) do
    with {:ok, session, _} <-
           PremiereEcoute.apply(%StartListeningSession{source: session.source, session_id: session.id, scope: scope}),
         {:ok, session, _} <-
           PremiereEcoute.apply(%SkipNextTrackListeningSession{source: session.source, session_id: session.id, scope: scope}) do
      {:noreply, assign(socket, :listening_session, session)}
    else
      {:error, reason} when is_binary(reason) -> {:noreply, put_flash(socket, :error, reason)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Cannot start session")}
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
      {:ok, session, _} -> {:noreply, assign(socket, :listening_session, session)}
      {:error, reason} when is_binary(reason) -> {:noreply, put_flash(socket, :error, reason)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Cannot stop session")}
    end
  end

  @impl true
  def handle_event("toggle", %{"flag" => flag}, %{assigns: assigns} = socket) do
    options = Map.update(assigns.listening_session.options, flag, true, fn v -> !v end)
    {:ok, listening_session} = ListeningSession.update(assigns.listening_session, %{options: options})
    {:noreply, assign(socket, :listening_session, listening_session)}
  end

  @impl true
  def handle_event("update_next_track", %{"next_track" => value}, %{assigns: assigns} = socket) do
    {value, _} = Integer.parse(value)
    options = Map.update(assigns.listening_session.options, "next_track", 0, fn _ -> value end)
    {:ok, listening_session} = ListeningSession.update(assigns.listening_session, %{options: options})
    {:noreply, assign(socket, :listening_session, listening_session)}
  end

  @impl true
  def handle_event("update_visibility", %{"visibility" => visibility}, %{assigns: assigns} = socket) do
    {:ok, listening_session} =
      ListeningSession.update(assigns.listening_session, %{visibility: String.to_existing_atom(visibility)})

    {:noreply, assign(socket, :listening_session, listening_session)}
  end

  @impl true
  def handle_event("change_overlay_score_type", params, socket) do
    score_type = params["score_type"] || params[:score_type] || "streamer"
    {:noreply, assign(socket, :overlay_score_type, score_type)}
  end

  @impl true
  def handle_event("open_overlay", _params, socket) do
    {:noreply, push_event(socket, "open_url", %{url: build_overlay_url(socket)})}
  end

  @impl true
  def handle_event("vote_track", %{"rating" => rating}, socket) do
    user_id = socket.assigns.current_scope.user.twitch.user_id

    Sessions.publish_message(%MessageSent{
      broadcaster_id: user_id,
      user_id: user_id,
      message: rating,
      is_streamer: true
    })

    {:noreply, assign(socket, :user_current_rating, rating)}
  end

  @impl true
  def handle_event("open_youtube_modal", _params, socket) do
    {:noreply, assign(socket, :show_youtube_modal, true)}
  end

  @impl true
  def handle_event("close_youtube_modal", _params, socket) do
    {:noreply, assign(socket, :show_youtube_modal, false)}
  end

  @impl true
  def handle_event(event, _params, socket) do
    {:noreply, put_flash(socket, :info, "Received event: #{event}")}
  end

  @impl true
  def handle_info({:session_updated, session}, socket) do
    socket
    |> assign(:listening_session, session)
    |> assign(:user_current_rating, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info(:vote_open, socket) do
    socket
    |> assign(:open_vote, true)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info(:vote_close, socket) do
    socket
    |> assign(:open_vote, false)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info(:refresh, %{assigns: %{current_scope: current_scope}} = socket) do
    Process.send_after(self(), :refresh, 1_000)

    {:ok, cached_session} = Cache.get(:sessions, current_scope.user.twitch.user_id)

    socket
    |> assign(:open_vote, !is_nil(cached_session))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:session_summary, _}, socket) do
    session_id = socket.assigns.session_id

    socket
    |> assign_async(:report, fn -> {:ok, %{report: Report.get_by(session_id: session_id)}} end)
    |> assign_async(:vote_trends, fn ->
      vote_data = VoteTrends.rolling_average(String.to_integer(session_id), :minute)
      {:ok, %{vote_trends: vote_data}}
    end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:flash, level, message}, socket) do
    {:noreply, put_flash(socket, level, message)}
  end

  @impl true
  def handle_info({:youtube_chapters_modal_closed}, socket) do
    {:noreply, assign(socket, :show_youtube_modal, false)}
  end

  @impl true
  def handle_info({:player, :start_track, state}, %{assigns: %{listening_session: session}} = socket) do
    case state do
      %{"context" => %{"type" => "playlist", "uri" => "spotify:playlist:" <> _playlist_id}} = payload ->
        case Playlist.add_track_to_playlist(session.playlist, payload) do
          {:ok, _} ->
            session = ListeningSession.get(session.id)
            {:ok, session} = ListeningSession.next_track(session)

            assign(socket, :listening_session, session)

          {:error, _} ->
            socket
        end

      _ ->
        socket
    end
    |> assign(:next_track_at, nil)
    |> assign(:player_state, state)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info(
        {:player, {:percent, percent}, state},
        %{assigns: %{listening_session: %ListeningSession{status: :active}, current_scope: scope}} = socket
      ) do
    if percent == round(100 * (1 - 30_000 / state["item"]["duration_ms"])) do
      ListeningSessionWorker.in_seconds(%{action: "votes_closing", user_id: scope.user.id}, 0)
    end

    {:noreply, assign(socket, :player_state, state)}
  end

  @impl true
  def handle_info(
        {:player, :end_track, state},
        %{assigns: %{listening_session: %ListeningSession{status: :active} = session, current_scope: scope}} = socket
      ) do
    next_track = Map.get(session.options, "next_track", 0)

    if next_track > 0 do
      action = if session.source == :album, do: "next_track", else: "next_playlist_track"

      {:ok, job} =
        ListeningSessionWorker.in_seconds(%{action: action, session_id: session.id, user_id: scope.user.id}, next_track)

      assign(socket, :next_track_at, job.scheduled_at)
    else
      socket
    end
    |> assign(:player_state, state)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:player, {:error, reason}, _state}, socket) do
    socket
    |> clear_flash()
    |> put_flash(:error, "Spotify down: #{inspect(reason)}")
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:player, _event, state}, socket) do
    {:noreply, assign(socket, :player_state, state)}
  end

  @impl true
  def handle_info(_event, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_async(:report, {:ok, %{report: report}}, socket) do
    {:noreply, assign(socket, :report, report)}
  end

  @impl true
  def handle_async(:vote_trends, {:ok, %{vote_trends: vote_trends}}, socket) do
    {:noreply, assign(socket, :vote_trends, vote_trends)}
  end

  @impl true
  def handle_async(:vote_trends, {:exit, reason}, socket) do
    Logger.error("Failed to load vote trends: #{inspect(reason)}")
    {:noreply, socket}
  end

  @impl true
  def handle_async(:report, {:exit, reason}, socket) do
    Logger.error("Failed to load session report: #{inspect(reason)}")
    {:noreply, socket}
  end

  def session_status_class(:preparing),
    do: "bg-gradient-to-r from-amber-500 to-orange-500 text-white shadow-md"

  def session_status_class(:active),
    do: "bg-gradient-primary text-white shadow-md"

  def session_status_class(:stopped),
    do: "bg-gradient-to-r from-slate-500 to-gray-600 text-white shadow-md"

  def session_tracks_rated(nil), do: 0
  def session_tracks_rated(report), do: report.session_summary["tracks_rated"]

  def vote_type_display(nil), do: "0-10"

  def vote_type_display(%{vote_options: vote_options}) when is_list(vote_options) do
    cond do
      vote_options == ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"] -> "0-10"
      vote_options == ["1", "2", "3", "4", "5"] -> "1-5"
      vote_options == ["smash", "pass"] -> "Smash or Pass"
      true -> "Custom (#{length(vote_options)} options)"
    end
  end

  def vote_type_display(_), do: "0-10"

  def session_streamer_score(nil), do: "N/A"

  def session_streamer_score(report) do
    case report.session_summary do
      %{"streamer_score" => score} when is_number(score) -> Float.round(score, 1)
      %{"streamer_score" => score} when is_binary(score) -> score
      _ -> "N/A"
    end
  end

  def track_streamer_score(_track_id, nil), do: "N/A"

  def track_streamer_score(track_id, report) do
    case Enum.find(report.track_summaries, &(&1["track_id"] == track_id)) do
      nil ->
        "N/A"

      track_summary ->
        case track_summary["streamer_score"] do
          score when is_number(score) -> Float.round(score, 1)
          score when is_binary(score) -> score
          _ -> "N/A"
        end
    end
  end

  def track_max_votes(_track_id, nil, _session), do: 0

  def track_max_votes(track_id, report, session) do
    track_vote_distribution(track_id, report, session)
    |> Enum.map(&elem(&1, 1))
    |> Enum.max(fn -> 0 end)
  end

  def vote_option_color(vote_option, session) do
    vote_options = session.vote_options
    total_options = length(vote_options)

    # Find the index of this vote option
    index = Enum.find_index(vote_options, &(&1 == vote_option)) || 0

    cond do
      # Special handling for smash/pass
      vote_option == "smash" ->
        "bg-green-500"

      vote_option == "pass" ->
        "bg-red-500"

      # For numeric options, use gradient based on position
      total_options <= 5 ->
        # For 1-5 scale, use yellow to green gradient
        case index do
          0 -> "bg-red-500"
          1 -> "bg-orange-500"
          2 -> "bg-yellow-500"
          3 -> "bg-green-400"
          4 -> "bg-green-500"
          _ -> "bg-blue-400"
        end

      total_options <= 10 ->
        case index do
          0 -> "bg-red-600"
          1 -> "bg-red-500"
          2 -> "bg-red-400"
          3 -> "bg-orange-500"
          4 -> "bg-yellow-500"
          5 -> "bg-yellow-400"
          6 -> "bg-green-400"
          7 -> "bg-blue-400"
          8 -> "bg-blue-500"
          9 -> "bg-blue-600"
          _ -> "bg-purple-400"
        end

      true ->
        colors = [
          "bg-red-500",
          "bg-orange-500",
          "bg-yellow-500",
          "bg-green-500",
          "bg-blue-500",
          "bg-purple-500",
          "bg-pink-500",
          "bg-indigo-500"
        ]

        Enum.at(colors, rem(index, length(colors)), "bg-gray-500")
    end
  end

  defp build_overlay_url(socket) do
    user_id = socket.assigns.current_scope.user.id
    get_current_overlay_url(socket.host_uri, user_id, socket.assigns.overlay_score_type)
  end

  defp get_current_overlay_url(host_uri, user_id, score_type) do
    base_url = "#{host_uri}/sessions/overlay/#{user_id}"

    case score_type do
      "streamer" -> "#{base_url}?score=streamer"
      "viewer" -> "#{base_url}?score=viewer"
      "both" -> "#{base_url}?score=viewer+streamer"
      "player" -> "#{base_url}?score=player"
      _ -> base_url
    end
  end

  def visibility_label(:private), do: "Private"
  def visibility_label(:protected), do: "Protected"
  def visibility_label(:public), do: "Public"

  def visibility_icon(:private) do
    ~S"""
    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
    </svg>
    """
  end

  def visibility_icon(:protected) do
    ~S"""
    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/>
    </svg>
    """
  end

  def visibility_icon(:public) do
    ~S"""
    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
    </svg>
    """
  end

  def visibility_description(:private), do: "Only you can view the retrospective"
  def visibility_description(:protected), do: "Authenticated users can view the retrospective"
  def visibility_description(:public), do: "Anyone with the link can view the retrospective"
end
