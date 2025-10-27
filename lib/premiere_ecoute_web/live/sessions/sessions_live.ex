defmodule PremiereEcouteWeb.Sessions.SessionsLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Sessions.ListeningSession

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: scope}} = socket) do
    socket
    |> assign(:show_delete_modal, false)
    |> assign(:session_to_delete, nil)
    |> assign_async(:sessions, fn -> {:ok, %{sessions: ListeningSession.page([where: [user_id: scope.user.id]], 1, 10)}} end)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("next-page", _params, %{assigns: %{current_scope: scope, sessions: sessions}} = socket) do
    socket
    |> assign_async(:sessions, fn ->
      {:ok, %{sessions: ListeningSession.next_page([where: [user_id: scope.user.id]], sessions)}}
    end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("navigate", %{"session_id" => session_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/sessions/#{session_id}")}
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
  def handle_event("confirm_delete", _params, %{assigns: %{current_scope: scope, session_to_delete: session_id}} = socket) do
    session_id
    |> ListeningSession.get()
    |> ListeningSession.delete()
    |> case do
      {:ok, session} ->
        if session.playlist do
          Playlist.delete(session.playlist)
        end

        put_flash(socket, :info, "Session deleted successfully")

      {:error, _} ->
        put_flash(socket, :error, "Failed to delete session")
    end
    |> assign(:show_delete_modal, false)
    |> assign(:session_to_delete, nil)
    |> assign_async(:sessions, fn -> {:ok, %{sessions: ListeningSession.all(where: [user_id: scope.user.id])}} end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def session_status_class(:preparing), do: "bg-yellow-600/20 text-yellow-400 border-yellow-500/30"
  def session_status_class(:active), do: "bg-green-600/20 text-green-400 border-green-500/30"
  def session_status_class(:stopped), do: "bg-gray-600/20 text-gray-400 border-gray-500/30"

  def session_status_icon(:preparing), do: "⏳"
  def session_status_icon(:active), do: "🎵"
  def session_status_icon(:stopped), do: "⏹️"

  # AIDEV-NOTE: visibility helper functions (issue #17)
  def visibility_class(:private), do: "bg-red-600/20 text-red-400 border-red-500/30"
  def visibility_class(:protected), do: "bg-blue-600/20 text-blue-400 border-blue-500/30"
  def visibility_class(:public), do: "bg-green-600/20 text-green-400 border-green-500/30"

  def visibility_icon(:private), do: "🔒"
  def visibility_icon(:protected), do: "🛡️"
  def visibility_icon(:public), do: "🌐"

  def visibility_label(:private), do: "Private"
  def visibility_label(:protected), do: "Protected"
  def visibility_label(:public), do: "Public"
end
