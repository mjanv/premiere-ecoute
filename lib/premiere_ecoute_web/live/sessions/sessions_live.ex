defmodule PremiereEcouteWeb.Sessions.SessionsLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Sessions.ListeningSession

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: scope}} = socket) do
    page = ListeningSession.page([where: [user_id: scope.user.id]], 1, 10)

    socket
    |> assign(:show_delete_modal, false)
    |> assign(:session_to_delete, nil)
    |> assign(:page, page)
    |> stream(:sessions, page.entries)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("next-page", _params, %{assigns: %{current_scope: scope, page: page}} = socket) do
    next_page = ListeningSession.next_page([where: [user_id: scope.user.id]], page)

    socket
    |> assign(:page, next_page)
    |> stream(:sessions, next_page.entries)
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

  # AIDEV-NOTE: Use stream_delete to update UI without full reload (template uses phx-update="stream")
  @impl true
  def handle_event("confirm_delete", _params, %{assigns: %{session_to_delete: session_id}} = socket) do
    session = ListeningSession.get(session_id)

    socket =
      case ListeningSession.delete(session) do
        {:ok, deleted_session} ->
          if deleted_session.playlist do
            Playlist.delete(deleted_session.playlist)
          end

          socket
          |> put_flash(:info, "Session deleted successfully")
          |> stream_delete(:sessions, deleted_session)

        {:error, _} ->
          put_flash(socket, :error, "Failed to delete session")
      end

    socket
    |> assign(:show_delete_modal, false)
    |> assign(:session_to_delete, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def session_status_class(:preparing), do: "bg-yellow-600/20 text-yellow-400 border-yellow-500/30"
  def session_status_class(:active), do: "bg-green-600/20 text-green-400 border-green-500/30"
  def session_status_class(:stopped), do: "bg-gray-600/20 text-gray-400 border-gray-500/30"

  def session_status_icon(:preparing), do: "⏳"
  def session_status_icon(:active), do: "🎵"
  def session_status_icon(:stopped), do: "⏹️"

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
