defmodule PremiereEcouteWeb.HomeLive do
  @moduledoc """
  Home page LiveView.

  Displays user's current listening session and latest billboard on the home page.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Billboards
  alias PremiereEcoute.Sessions.ListeningSession

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

    socket
    |> assign(:current_user, User.preload(current_user))
    |> assign(:current_session, ListeningSession.current_session(current_user))
    |> load_recent_billboards()
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  defp load_recent_billboards(%{assigns: assigns} = socket) do
    if assigns.current_scope do
      latest_billboard =
        Billboards.all(
          where: [user_id: assigns.current_scope.user.id],
          order_by: [desc: :inserted_at],
          limit: 1
        )
        |> List.first()

      assign(socket, :latest_billboard, latest_billboard)
    else
      assign(socket, :latest_billboard, nil)
    end
  end
end
