defmodule PremiereEcouteWeb.HomepageLive do
  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user
    socket = assign(socket, :current_user, User.preload(current_user))
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
