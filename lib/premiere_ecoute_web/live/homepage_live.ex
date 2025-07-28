defmodule PremiereEcouteWeb.HomepageLive do
  use PremiereEcouteWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # AIDEV-NOTE: Get current user from authentication scope for conditional UI
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

    # AIDEV-NOTE: Load user's followed channels if authenticated
    current_user_with_channels =
      if current_user do
        PremiereEcoute.Repo.preload(current_user, :channels)
      else
        current_user
      end

    socket = assign(socket, :current_user, current_user_with_channels)
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
