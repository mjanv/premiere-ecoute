defmodule PremiereEcouteWeb.HomepageLive do
  @moduledoc false

  use PremiereEcouteWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # If user is authenticated, redirect to /home
    if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
      socket = redirect(socket, to: "/home")
      {:ok, socket}
    else
      {:ok, assign(socket, show_modal: false)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  # AIDEV-NOTE: Handle modal toggle for role selection
  @impl true
  def handle_event("toggle_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: !socket.assigns.show_modal)}
  end
end
