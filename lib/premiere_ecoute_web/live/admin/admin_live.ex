defmodule PremiereEcouteWeb.Admin.AdminLive do
  @moduledoc false

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.Scores

  def mount(_params, _session, socket) do
    socket
    |> assign(:stats, %{
      users_count: User.count(:id),
      sessions_count: Sessions.ListeningSession.count(:id),
      albums_count: Album.count(:id),
      votes_count: Scores.Vote.count(:id),
      polls_count: Scores.Poll.count(:id)
    })
    |> assign(:event_store, %{
      stream: "accounts",
      page: 1,
      size: 10,
      events: PremiereEcoute.paginate("accounts", page: 1, size: 10)
    })
    |> then(fn socket -> {:ok, socket} end)
  end

  # AIDEV-NOTE: handle event store form changes and pagination
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
