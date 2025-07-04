defmodule PremiereEcouteWeb.HomepageLive do
  use PremiereEcouteWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # AIDEV-NOTE: Get current user from authentication scope for conditional UI
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user
    socket = assign(socket, :current_user, current_user)
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
