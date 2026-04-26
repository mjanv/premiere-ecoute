defmodule PremiereEcouteWeb.Sessions.AlbumPickAdminLive do
  @moduledoc """
  Streamer administration page for the random album pick list.

  Lists all albums in the streamer's pick list, allows adding new albums via
  Spotify search, and supports removal of individual entries.
  """

  use PremiereEcouteWeb, :live_view

  alias Phoenix.LiveView.AsyncResult
  alias PremiereEcoute.Sessions.AlbumPicks

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    PremiereEcoute.PubSub.subscribe("album_picks:#{user.id}")

    socket
    |> stream(:picks, AlbumPicks.list_for_user(user.id))
    |> assign(:picks_count, AlbumPicks.count_for_user(user.id))
    |> assign(:viewer_submit_url, url(~p"/sessions/#{user.username}/pick"))
    |> assign(:show_clear_modal, false)
    |> assign(:search_form, to_form(%{"query" => ""}))
    |> assign(:search_albums, AsyncResult.ok([]))
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_event("search_albums", %{"query" => query}, socket) when byte_size(query) > 2 do
    socket
    |> assign(:search_albums, AsyncResult.loading())
    |> start_async(:search, fn -> PremiereEcoute.Apis.spotify().search_albums(query) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("search_albums", _params, socket) do
    socket
    |> assign(:search_albums, AsyncResult.ok([]))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("add_album", %{"album_id" => album_id}, socket) do
    user_id = socket.assigns.current_scope.user.id

    album =
      case socket.assigns.search_albums do
        %{result: albums} when is_list(albums) -> Enum.find(albums, &(Map.get(&1.provider_ids, :spotify) == album_id))
        _ -> nil
      end

    case album do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Album not found in search results"))}

      album ->
        attrs = %{
          album_id: Map.get(album.provider_ids, :spotify),
          name: album.name,
          artist: album.artist.name,
          cover_url: album.cover_url
        }

        case AlbumPicks.add_entry(user_id, attrs) do
          {:ok, pick} ->
            socket
            |> stream_insert(:picks, pick, at: 0)
            |> assign(:picks_count, socket.assigns.picks_count + 1)
            |> assign(:search_albums, AsyncResult.ok([]))
            |> assign(:search_form, to_form(%{"query" => ""}))
            |> put_flash(:info, gettext("Album added"))
            |> then(fn socket -> {:noreply, socket} end)

          {:error, _} ->
            {:noreply, put_flash(socket, :error, gettext("Could not add album"))}
        end
    end
  end

  def handle_event("remove_album", %{"pick_id" => pick_id_str}, socket) do
    user_id = socket.assigns.current_scope.user.id
    {pick_id, ""} = Integer.parse(pick_id_str)

    case AlbumPicks.remove_entry(user_id, pick_id) do
      {:ok, pick} ->
        socket
        |> stream_delete(:picks, pick)
        |> assign(:picks_count, socket.assigns.picks_count - 1)
        |> put_flash(:info, gettext("Album removed"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, gettext("Album not found"))}
    end
  end

  def handle_event("open_clear_modal", _params, socket) do
    {:noreply, assign(socket, :show_clear_modal, true)}
  end

  def handle_event("close_clear_modal", _params, socket) do
    {:noreply, assign(socket, :show_clear_modal, false)}
  end

  def handle_event("confirm_clear_all", _params, socket) do
    user_id = socket.assigns.current_scope.user.id
    AlbumPicks.clear_all(user_id)

    socket
    |> stream(:picks, [], reset: true)
    |> assign(:picks_count, 0)
    |> assign(:show_clear_modal, false)
    |> put_flash(:info, gettext("List cleared"))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:pick_added, pick}, socket) do
    socket
    |> stream_insert(:picks, pick, at: 0)
    |> assign(:picks_count, socket.assigns.picks_count + 1)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_async(:search, {:ok, {:ok, albums}}, socket) do
    socket
    |> assign(:search_albums, AsyncResult.ok(albums))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:search, {:ok, {:error, reason}}, %{assigns: assigns} = socket) do
    socket
    |> assign(:search_albums, AsyncResult.failed(assigns.search_albums, {:error, reason}))
    |> put_flash(:error, gettext("Search failed. Please try again."))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:search, {:exit, reason}, %{assigns: assigns} = socket) do
    socket
    |> assign(:search_albums, AsyncResult.failed(assigns.search_albums, {:error, reason}))
    |> put_flash(:error, gettext("Search failed. Please try again."))
    |> then(fn socket -> {:noreply, socket} end)
  end
end
