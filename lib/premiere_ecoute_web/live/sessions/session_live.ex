defmodule PremiereEcouteWeb.Sessions.SessionLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Core
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession
  alias PremiereEcoute.Sessions.Scores.Events.MessageSent
  alias PremiereEcoute.Sessions.Scores.Report
  alias PremiereEcoute.Sessions.Scores.Vote
  alias PremiereEcouteWeb.Sessions.Components.SpotifyPlayer

  @impl true
  def mount(%{"id" => session_id}, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :refresh, 0)
    end

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
           {:ok, %{report: Report.get_by(session_id: session_id)}}
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
        %{assigns: %{listening_session: session, current_scope: scope}} = socket
      ) do
    %StartListeningSession{session_id: session.id, scope: scope}
    |> PremiereEcoute.apply()
    |> case do
      {:ok, session, _} -> {:noreply, assign(socket, :listening_session, session)}
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
      {:error, _} -> {:noreply, put_flash(socket, :error, "Cannot stop session")}
    end
  end

  @impl true
  def handle_event("toggle", %{"flag" => flag}, %{assigns: assigns} = socket) do
    {:noreply, assign(socket, :show, Map.update!(assigns.show, String.to_atom(flag), fn v -> !v end))}
  end

  @impl true
  def handle_event("open_overlay", _params, socket) do
    overlay_url = "#{socket.host_uri}/sessions/#{socket.assigns.listening_session.id}/overlay"
    {:noreply, push_event(socket, "open_url", %{url: overlay_url})}
  end

  @impl true
  def handle_event("copy_overlay_url", _params, socket) do
    overlay_url = "#{socket.host_uri}/sessions/#{socket.assigns.listening_session.id}/overlay"

    {:noreply,
     socket
     |> push_event("copy_to_clipboard", %{text: overlay_url})
     |> put_flash(:info, "Overlay URL copied to clipboard!")}
  end

  @impl true
  def handle_event("vote_track", %{"rating" => rating}, socket) do
    user_id = socket.assigns.current_scope.user.twitch_user_id

    Core.dispatch(%MessageSent{
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
    socket = assign(socket, :listening_session, session)
    socket = assign(socket, :user_current_rating, nil)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, 2_500)
    {:noreply, SpotifyPlayer.refresh_state(socket)}
  end

  @impl true
  def handle_info(%Vote{} = _vote, socket) do
    session_id = socket.assigns.session_id

    {:noreply,
     socket
     |> assign_async(:report, fn ->
       {:ok, %{report: Report.get_by(session_id: session_id)}}
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

  def session_vote_options(nil), do: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]

  def session_vote_options(%{vote_options: vote_options}) when is_list(vote_options) do
    # For the voting interface, we need to filter out "0" if it exists since it's typically not used for voting
    case vote_options do
      # Remove "0" for voting interface
      ["0" | rest] -> rest
      options -> options
    end
  end

  def session_vote_options(_), do: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]

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

  # AIDEV-NOTE: Get vote distribution histogram data for a specific track from raw votes and polls
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

    # Combine both distributions and ensure all session vote options are present
    for rating <- session_vote_options(session) do
      individual_count = Map.get(individual_distribution, rating, 0)
      poll_count = Map.get(poll_distribution, rating, 0)
      total_count = individual_count + poll_count
      {rating, total_count}
    end
  end

  # AIDEV-NOTE: Get the maximum vote count for highlighting in histogram
  def track_max_votes(_track_id, nil, _session), do: 0

  def track_max_votes(track_id, report, session) do
    track_vote_distribution(track_id, report, session)
    |> Enum.map(&elem(&1, 1))
    |> Enum.max(fn -> 0 end)
  end

  # AIDEV-NOTE: Get dynamic color for vote option based on its position and type
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
          # 1st option
          0 -> "bg-red-500"
          # 2nd option
          1 -> "bg-orange-500"
          # 3rd option
          2 -> "bg-yellow-500"
          # 4th option
          3 -> "bg-green-400"
          # 5th option
          4 -> "bg-green-500"
          _ -> "bg-blue-400"
        end

      total_options <= 10 ->
        # For larger scales like 0-10, use full gradient
        case index do
          # 1st option
          0 -> "bg-red-600"
          # 2nd option
          1 -> "bg-red-500"
          # 3rd option
          2 -> "bg-red-400"
          # 4th option
          3 -> "bg-orange-500"
          # 5th option
          4 -> "bg-yellow-500"
          # 6th option
          5 -> "bg-yellow-400"
          # 7th option
          6 -> "bg-green-400"
          # 8th option
          7 -> "bg-blue-400"
          # 9th option
          8 -> "bg-blue-500"
          # 10th option
          9 -> "bg-blue-600"
          _ -> "bg-purple-400"
        end

      true ->
        # For custom options with many choices, cycle through colors
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
end
