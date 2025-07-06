defmodule PremiereEcouteWeb.Sessions.OverlayLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Report
  alias PremiereEcoute.Sessions.Scores.Vote

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    listening_session =
      case Integer.parse(id) do
        {int_id, ""} -> ListeningSession.get(int_id)
        _ -> nil
      end

    case listening_session do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Session not found")
         |> assign(:session_id, id)
         |> assign(:listening_session, nil)
         |> assign(:report, nil)}

      listening_session ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "session:#{id}")
        end

        {:ok,
         socket
         |> assign(:session_id, id)
         |> assign(:listening_session, listening_session)
         |> assign(:report, nil)
         |> assign_async(:report, fn ->
           {:ok, %{report: Report.get_by(session_id: String.to_integer(id))}}
         end)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:track_changed, _track}, socket) do
    # Reload stats when track changes
    session_id = socket.assigns.session_id

    {:noreply,
     socket
     |> assign_async(:report, fn ->
       {:ok, %{report: Report.get_by(session_id: String.to_integer(session_id))}}
     end)}
  end

  @impl true
  def handle_info({:score_updated, _score_data}, socket) do
    # Reload stats when scores are updated
    session_id = socket.assigns.session_id

    {:noreply,
     socket
     |> assign_async(:report, fn ->
       {:ok, %{report: Report.get_by(session_id: String.to_integer(session_id))}}
     end)}
  end

  @impl true
  def handle_info(%Vote{} = _vote, socket) do
    # AIDEV-NOTE: Handle vote PubSub message - reload stats from updated report
    session_id = socket.assigns.session_id

    {:noreply,
     socket
     |> assign_async(:report, fn ->
       {:ok, %{report: Report.get_by(session_id: String.to_integer(session_id))}}
     end)}
  end

  @impl true
  def handle_info(_event, socket) do
    # Ignore other events
    {:noreply, socket}
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

  # AIDEV-NOTE: Helper functions to extract data from Report struct for template use
  def current_average_score(nil), do: 0.0

  def current_average_score(report) do
    case report.session_summary do
      %{"viewer_score" => score} when is_number(score) -> Float.round(score, 2)
      _ -> 0.0
    end
  end

  def total_votes(nil), do: 0
  def total_votes(report), do: report.unique_votes || 0

  def tracks_rated(nil), do: 0

  def tracks_rated(report) do
    case report.session_summary do
      %{"tracks_rated" => count} when is_integer(count) -> count
      _ -> 0
    end
  end
end
