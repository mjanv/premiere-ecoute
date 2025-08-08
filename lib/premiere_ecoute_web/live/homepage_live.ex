defmodule PremiereEcouteWeb.HomepageLive do
  use PremiereEcouteWeb, :live_view

  # AIDEV-NOTE: Redirect authenticated users to /home
  @impl true
  def mount(_params, _session, socket) do
    # If user is authenticated, redirect to /home
    if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
      socket = redirect(socket, to: "/home")
      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
