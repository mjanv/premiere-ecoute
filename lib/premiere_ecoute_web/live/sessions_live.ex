defmodule PremiereEcouteWeb.SessionsLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Sessions.ListeningSession

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "All Sessions")
     |> assign_async(:sessions_data, fn -> {:ok, %{sessions_data: load_sessions_data()}} end)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("navigate_to_session", %{"session_id" => session_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/session/#{session_id}")}
  end

  defp load_sessions_data do
    sessions = ListeningSession.all()
    grouped_sessions = Enum.group_by(sessions, & &1.status)

    %{
      sessions: sessions,
      active_sessions: Map.get(grouped_sessions, :active, []),
      preparing_sessions: Map.get(grouped_sessions, :preparing, []),
      stopped_sessions: Map.get(grouped_sessions, :stopped, [])
    }
  rescue
    error ->
      Logger.error("Failed to load sessions: #{inspect(error)}")

      %{
        sessions: [],
        active_sessions: [],
        preparing_sessions: [],
        stopped_sessions: [],
        error: "Failed to load sessions"
      }
  end

  def session_status_class(:preparing), do: "bg-yellow-900/30 text-yellow-400 border-yellow-700"
  def session_status_class(:active), do: "bg-green-900/30 text-green-400 border-green-700"
  def session_status_class(:stopped), do: "bg-gray-700 text-gray-300 border-gray-600"

  def session_status_icon(:preparing), do: "⏳"
  def session_status_icon(:active), do: "🎵"
  def session_status_icon(:stopped), do: "⏹️"

  def format_datetime(nil), do: "Not started"

  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  def time_ago(nil), do: ""

  def time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      diff < 86_400 -> "#{div(diff, 3600)} hours ago"
      true -> "#{div(diff, 86400)} days ago"
    end
  end
end
