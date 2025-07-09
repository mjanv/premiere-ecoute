defmodule PremiereEcouteWeb.Sessions.SessionsLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Sessions.ListeningSession

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: scope}} = socket) do
    socket
    |> assign(:show_delete_modal, false)
    |> assign(:session_to_delete, nil)
    |> assign_async(:sessions_data, fn -> {:ok, %{sessions_data: load(scope)}} end)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("navigate", %{"session_id" => session_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/session/#{session_id}")}
  end

  @impl true
  def handle_event("delete_session", %{"session_id" => session_id}, socket) do
    socket
    |> assign(:show_delete_modal, true)
    |> assign(:session_to_delete, session_id)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    socket
    |> assign(:show_delete_modal, false)
    |> assign(:session_to_delete, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event(
        "confirm_delete",
        _params,
        %{assigns: %{session_to_delete: session_id, current_scope: scope}} = socket
      ) do
    session_id
    |> ListeningSession.delete()
    |> case do
      {:ok, _} -> put_flash(socket, :info, "Session deleted successfully")
      {:error, _} -> put_flash(socket, :error, "Failed to delete session")
    end
    |> assign(:show_delete_modal, false)
    |> assign(:session_to_delete, nil)
    |> assign_async(:sessions_data, fn -> {:ok, %{sessions_data: load(scope)}} end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  defp load(scope) do
    sessions = ListeningSession.all(where: [user_id: scope.user.id])
    grouped_sessions = Enum.group_by(sessions, & &1.status)

    %{
      sessions: sessions,
      active_sessions: Map.get(grouped_sessions, :active, []),
      preparing_sessions: Map.get(grouped_sessions, :preparing, []),
      stopped_sessions: Map.get(grouped_sessions, :stopped, [])
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
