defmodule PremiereEcouteWeb.Sessions.Discography.AlbumSelectionLive do
  use PremiereEcouteWeb, :live_view

  alias Phoenix.LiveView.AsyncResult
  alias PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    PremiereEcouteWeb.PubSub.subscribe("listening_sessions")

    socket
    |> assign(:page_title, "Streamer Dashboard")
    |> assign(:search_form, to_form(%{"query" => ""}))
    |> assign(:search_albums, AsyncResult.ok([]))
    |> assign(:selected_album, AsyncResult.ok(nil))
    |> assign(:current_scope, socket.assigns[:current_scope] || %{})
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_event("search_albums", %{"query" => query}, socket) when byte_size(query) > 2 do
    socket
    |> assign(:search_albums, AsyncResult.loading())
    |> start_async(:search, fn -> PremiereEcoute.search_albums(query) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("search_albums", _params, socket), do: {:noreply, socket}

  def handle_event("select_album", %{"album_id" => album_id}, socket) do
    socket
    |> assign(:search_albums, AsyncResult.ok([]))
    |> assign(:selected_album, AsyncResult.loading())
    |> start_async(:select, fn -> PremiereEcoute.get_album(album_id) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("prepare_session", _params, %{assigns: %{selected_album: nil}} = socket) do
    {:noreply, put_flash(socket, :error, "Please select an album first")}
  end

  def handle_event(
        "prepare_session",
        _params,
        %{assigns: %{selected_album: %{result: album}}} = socket
      ) do
    %PrepareListeningSession{user_id: get_user_id(socket), album_id: album.spotify_id}
    |> PremiereEcoute.apply()
    |> case do
      {:ok, session, _} -> push_navigate(socket, to: ~p"/session/#{session}")
      {:error, _} -> put_flash(socket, :error, "Cannot create the listening session")
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_async(:search, {:ok, result}, %{assigns: assigns} = socket) do
    case result do
      {:ok, albums} ->
        socket
        |> assign(:search_albums, AsyncResult.ok(albums))

      {:error, reason} ->
        socket
        |> assign(:search_albums, AsyncResult.failed(assigns.search_albums, {:error, reason}))
        |> put_flash(:error, "Search failed. Please try again.")
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:search, {:exit, reason}, %{assigns: assigns} = socket) do
    socket
    |> assign(:search_albums, AsyncResult.failed(assigns.search_albums, {:error, reason}))
    |> put_flash(:error, "Search failed. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:select, {:ok, {:ok, album}}, socket) do
    socket
    |> assign(:selected_album, AsyncResult.ok(album))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:select, {:ok, {:error, reason}}, %{assigns: assigns} = socket) do
    socket
    |> assign(:selected_album, AsyncResult.failed(assigns.selected_album, {:error, reason}))
    |> put_flash(:error, "Selection failed. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:select, {:exit, reason}, %{assigns: assigns} = socket) do
    socket
    |> assign(:selected_album, AsyncResult.failed(assigns.selected_album, {:error, reason}))
    |> put_flash(:error, "Selection failed. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  defp format_duration(duration_ms) when is_integer(duration_ms) do
    minutes = div(duration_ms, 60_000)
    seconds = div(rem(duration_ms, 60_000), 1000)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end

  defp format_duration(_), do: "0:00"

  defp get_user_id(socket) do
    case socket.assigns.current_scope do
      %{user: %{id: user_id}} -> user_id
      _ -> nil
    end
  end
end
