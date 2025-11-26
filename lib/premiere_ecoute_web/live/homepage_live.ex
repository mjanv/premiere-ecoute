defmodule PremiereEcouteWeb.HomepageLive do
  @moduledoc """
  Public homepage LiveView.

  Displays the landing page for non-authenticated users and redirects authenticated users to their home dashboard.
  """

  use PremiereEcouteWeb, :live_view

  import PremiereEcouteWeb.Components.Modal

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
      {:ok, redirect(socket, to: "/home")}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
