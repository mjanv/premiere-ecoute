defmodule PremiereEcouteWeb.Admin.AdminLive do
  @moduledoc """
  Admin dashboard LiveView.

  Displays system statistics and event store browser with pagination for monitoring users, sessions, albums, billboards, and goals.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Billboards.Billboard
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Donations.Goal
  alias PremiereEcoute.Sessions.ListeningSession

  def mount(_params, _session, socket) do
    socket
    |> assign(:stats, %{
      users_count: User.count(:id),
      sessions_count: ListeningSession.count(:id),
      albums_count: Album.count(:id),
      billboards_count: Billboard.count(:id),
      goals_count: Goal.count(:id)
    })
    |> assign(:event_store, %{
      stream: "users",
      page: 1,
      size: 10,
      events: PremiereEcoute.paginate("users", page: 1, size: 10)
    })
    |> then(fn socket -> {:ok, socket} end)
  end

  def handle_event("change_stream", %{"stream" => stream}, socket) do
    events = PremiereEcoute.paginate(stream, page: 1, size: socket.assigns.event_store.size)
    event_store = %{socket.assigns.event_store | stream: stream, page: 1, events: events}
    {:noreply, assign(socket, :event_store, event_store)}
  end

  def handle_event("change_page", %{"page" => page_str}, socket) do
    page = String.to_integer(page_str)
    events = PremiereEcoute.paginate(socket.assigns.event_store.stream, page: page, size: socket.assigns.event_store.size)
    event_store = %{socket.assigns.event_store | page: page, events: events}
    {:noreply, assign(socket, :event_store, event_store)}
  end
end
