defmodule PremiereEcouteWeb.Admin.AdminAlbumsLive do
  @moduledoc """
  Admin albums management LiveView.

  Provides paginated album listing with detailed view modal, deletion functionality, and album/track statistics for administrators.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track

  def mount(_params, _session, socket) do
    socket
    |> assign(:page, Album.page([], 1, 10))
    |> assign(:album_stats, album_stats())
    |> assign(:selected_album, nil)
    |> assign(:show_modal, false)
    |> then(fn socket -> {:ok, socket} end)
  end

  def handle_params(params, _url, socket) do
    page_number = String.to_integer(params["page"] || "1")
    page_size = String.to_integer(params["per_page"] || "10")

    socket
    |> assign(:page, Album.page([], page_number, page_size))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("show_album_modal", %{"album_id" => album_id}, socket) do
    socket
    |> assign(:selected_album, Album.get(album_id))
    |> assign(:show_modal, true)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("close_modal", _params, socket) do
    socket
    |> assign(:selected_album, nil)
    |> assign(:show_modal, false)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("delete_album", %{"album_id" => album_id}, %{assigns: %{page: page}} = socket) do
    album_id
    |> Album.get()
    |> Album.delete()
    |> case do
      {:ok, _} ->
        socket
        |> assign(:page, Album.page([], page.page_number, page.page_size))
        |> put_flash(:info, gettext("Album deleted successfully"))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("Cannot delete album"))
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  defp pagination_range(current_page, total_pages) do
    cond do
      total_pages <= 7 ->
        1..total_pages |> Enum.to_list()

      current_page <= 4 ->
        [1, 2, 3, 4, 5, :ellipsis, total_pages]

      current_page >= total_pages - 3 ->
        [1, :ellipsis, total_pages - 4, total_pages - 3, total_pages - 2, total_pages - 1, total_pages]

      true ->
        [1, :ellipsis, current_page - 1, current_page, current_page + 1, :ellipsis, total_pages]
    end
  end

  defp album_stats do
    %{
      total_albums: Album.count(:id),
      total_tracks: Track.count(:id)
    }
  end
end
