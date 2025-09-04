defmodule PremiereEcouteWeb.Sessions.SessionLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Apis.PlayerSupervisor
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Presence
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.ListeningSession
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
        Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "playback:#{current_scope.user.id}")
        Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "session:#{id}")
      end

      {:ok, _} = PlayerSupervisor.start(current_scope.user.id)
      {:ok, cached_session} = Cache.get(:sessions, current_scope.user.twitch.user_id)

      socket
      |> assign(:listening_session, listening_session)
      |> assign(:open_vote, !is_nil(cached_session))
      |> assign(:player_state, nil)
      |> assign(:session_id, id)
      |> assign(:show, %{votes: true, scores: true, next_track: 0})
      |> assign(:user_current_rating, nil)
      |> assign(:report, nil)
      |> assign(:overlay_score_type, "streamer")
      |> assign(:vote_trends, nil)
      |> assign(:next_track_at, nil)
      |> assign_async(:report, fn -> {:ok, %{report: Report.get_by(session_id: id)}} end)
      |> assign_async(:vote_trends, fn ->
        vote_data = VoteTrends.rolling_average(String.to_integer(id), :minute)
        {:ok, %{vote_trends: vote_data}}
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
    %StartListeningSession{source: session.source, session_id: session.id, scope: scope}
    |> PremiereEcoute.apply()
    |> case do
      {:ok, session, _} -> {:noreply, assign(socket, :listening_session, session)}
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
    {:noreply, assign(socket, :show, Map.update!(assigns.show, String.to_existing_atom(flag), fn v -> !v end))}
  end

  @impl true
  def handle_event("update_next_track", %{"next_track" => value}, %{assigns: assigns} = socket) do
    case Integer.parse(value) do
      {value, _} when value >= 0 and value <= 60 -> {:noreply, assign(socket, :show, Map.put(assigns.show, :next_track, value))}
      _ -> {:noreply, socket}
    end
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
    |> assign(:current_scope, Accounts.maybe_renew_token(socket, :spotify))
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
  def handle_info(
        {:player, :end_track, state},
        %{assigns: %{show: show, listening_session: session, current_scope: scope}} = socket
      ) do
    if show[:next_track] > 0 do
      {:ok, job} =
        ListeningSessionWorker.in_seconds(
          %{action: "next_track", session_id: session.id, user_id: scope.user.id},
          show[:next_track]
        )

      socket
      |> assign(:next_track_at, job.scheduled_at)
      |> put_flash(:info, "Next track in #{show[:next_track]} seconds")
    else
      socket
    end
    |> assign(:player_state, state)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:player, :start_track, state}, %{assigns: %{listening_session: session}} = socket) do
    case state do
      %{"context" => %{"type" => "playlist"}} = payload ->
        case Playlist.add_track_to_playlist(session.playlist, payload) do
          {:ok, _} ->
            session = ListeningSession.get(session.id)
            {:ok, session} = ListeningSession.next_track(session) |> IO.inspect()

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

  def track_score(_track_id, nil), do: "N/A"

  def track_score(track_id, report) do
    case Enum.find(report.track_summaries, &(&1["track_id"] == track_id)) do
      nil ->
        "N/A"

      track_summary ->
        case track_summary["viewer_score"] do
          score when is_number(score) -> Float.round(score, 1)
          score when is_binary(score) -> score
          _ -> "N/A"
        end
    end
  end

  def track_votes_count(_track_id, nil), do: 0

  def track_votes_count(track_id, report) do
    case Enum.find(report.track_summaries, &(&1["track_id"] == track_id)) do
      nil -> 0
      track_summary -> track_summary["unique_votes"] || 0
    end
  end

  def session_average_score(nil), do: "N/A"

  def session_average_score(report) do
    case report.session_summary do
      %{"viewer_score" => score} when is_number(score) -> Float.round(score, 1)
      %{"viewer_score" => score} when is_binary(score) -> score
      _ -> "N/A"
    end
  end

  def session_total_votes(nil), do: 0
  def session_total_votes(report), do: report.session_summary["unique_votes"]

  def session_unique_voters(nil), do: 0
  def session_unique_voters(report), do: report.session_summary["unique_voters"]

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

  def session_vote_options(nil), do: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
  def session_vote_options(%{vote_options: vote_options}) when is_list(vote_options), do: vote_options

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

  def track_vote_distribution(_track_id, nil, session),
    do: for(rating <- session_vote_options(session), do: {rating, 0})

  def track_vote_distribution(track_id, report, session) do
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
          # Handle both numeric and string ratings
          rating = if String.match?(rating_str, ~r/^\d+$/), do: String.to_integer(rating_str), else: rating_str
          Map.update(inner_acc, rating, count, &(&1 + count))
        end)
      end)

    for rating <- session_vote_options(session) do
      individual_count = Map.get(individual_distribution, rating, 0)
      poll_count = Map.get(poll_distribution, rating, 0)
      total_count = individual_count + poll_count
      {rating, total_count}
    end
  end

  def track_max_votes(_track_id, nil, _session), do: 0

  def track_max_votes(track_id, report, session) do
    track_vote_distribution(track_id, report, session)
    |> Enum.map(&elem(&1, 1))
    |> Enum.max(fn -> 0 end)
  end

  def vote_option_color(vote_option, session) do
    vote_options = session_vote_options(session)
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
    get_current_overlay_url(socket.host_uri, socket.assigns.listening_session.id, socket.assigns.overlay_score_type)
  end

  defp get_current_overlay_url(host_uri, session_id, score_type) do
    base_url = "#{host_uri}/sessions/#{session_id}/overlay"

    case score_type do
      "streamer" -> "#{base_url}?score=streamer"
      "viewer" -> "#{base_url}?score=viewer"
      "both" -> "#{base_url}?score=viewer+streamer"
      "player" -> "#{base_url}?score=player"
      _ -> base_url
    end
  end

  # Calculate dynamic bar height based on vote count and maximum votes in the dataset.
  # Ensures bars scale proportionally and don't exceed container height.
  defp calculate_bar_height(votes, max_votes, container_height, min_height) do
    cond do
      votes == 0 ->
        0

      max_votes == 0 ->
        min_height

      true ->
        # Use 85% of container height for maximum bar
        max_bar_height = container_height * 0.85
        scale_factor = max_bar_height / max_votes
        calculated_height = votes * scale_factor

        # Ensure minimum height for visibility
        max(calculated_height, min_height)
        |> round()
    end
  end

  # Format vote count for display, using abbreviated format for large numbers.
  defp format_vote_count(count) when is_integer(count) do
    cond do
      count < 1000 -> Integer.to_string(count)
      count < 10_000 -> "#{Float.round(count / 1000, 1)}k"
      count < 1_000_000 -> "#{round(count / 1000)}k"
      true -> "#{Float.round(count / 1_000_000, 1)}M"
    end
  end

  defp format_vote_count(_), do: "0"

  # Determine if vote count should be displayed inside or above the bar based on bar height.
  defp vote_count_position(bar_height, min_height_for_inside \\ 20) do
    if bar_height >= min_height_for_inside do
      :inside
    else
      :above
    end
  end

  # Calculate responsive font size class for vote counts based on maximum vote count.
  defp vote_count_font_size(max_votes) do
    cond do
      max_votes < 100 -> "text-sm"
      max_votes < 1000 -> "text-xs"
      true -> "text-xs"
    end
  end

  # Calculate responsive padding for histogram bars based on number of vote options.
  defp bar_padding_class(vote_option_count) do
    cond do
      vote_option_count <= 5 -> "px-1"
      vote_option_count <= 10 -> "px-0.5"
      vote_option_count <= 15 -> "px-0"
      true -> ""
    end
  end
end
