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
    |> assign_async(:sessions, fn -> {:ok, %{sessions: ListeningSession.all(where: [user_id: scope.user.id])}} end)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
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
end
