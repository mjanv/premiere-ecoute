defmodule PremiereEcouteWeb.HomepageLive do
  @moduledoc """
  Public homepage LiveView.

  Displays the landing page for non-authenticated users and redirects authenticated users to their home dashboard.
  """

  use PremiereEcouteWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
      {:ok, redirect(socket, to: "/home")}
    else
      # AIDEV-NOTE: clear error flash — unauthenticated redirects from protected routes
      # (require_authenticated_user) land here with "You must log in" which is misleading
      # since the homepage already has Twitch login buttons. Auth-specific errors
      # (e.g. "Twitch authentication failed") are intentional and kept as :error flashes
      # but cleared here too since the user can simply retry via the buttons.
      {:ok, clear_flash(socket, :error)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
