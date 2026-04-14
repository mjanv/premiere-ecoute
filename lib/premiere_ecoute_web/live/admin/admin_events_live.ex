defmodule PremiereEcouteWeb.Admin.AdminEventsLive do
  @moduledoc """
  Admin event store browser LiveView.

  Full-featured paginated event store browser. Supports stream switching,
  pagination, and per-stream filtering across all known streams.
  """

  use PremiereEcouteWeb, :live_view

  @known_streams ~w(users wantlists sessions albums artists billboards goals reviews)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:stream, "users")
     |> assign(:page, 1)
     |> assign(:size, 20)
     |> assign(:events, load_events("users", 1, 20))}
  end

  @impl true
  def handle_event("change_stream", %{"stream" => stream}, socket) do
    stream = if stream in @known_streams, do: stream, else: socket.assigns.stream
    events = load_events(stream, 1, socket.assigns.size)
    {:noreply, assign(socket, stream: stream, page: 1, events: events)}
  end

  def handle_event("change_page", %{"page" => page_str}, socket) do
    page = String.to_integer(page_str)
    events = load_events(socket.assigns.stream, page, socket.assigns.size)
    {:noreply, assign(socket, page: page, events: events)}
  end

  # AIDEV-NOTE: rescue ArgumentError from JsonbSerializer.keys_to_atoms/1 which
  # crashes on String.to_existing_atom for stale field names in old stored events.
  defp load_events(stream, page, size) do
    PremiereEcoute.paginate(stream, page: page, size: size)
  rescue
    ArgumentError -> []
  end

  defp short_type(nil), do: "Unknown"

  defp short_type(type) do
    type
    |> String.replace("Elixir.", "")
    |> String.split(".")
    |> List.last()
  end

  defp known_streams, do: @known_streams
end
