defmodule PremiereEcouteWeb.Admin.AdminAlbumsLive do
  @moduledoc """
  Admin albums management LiveView.

  Provides paginated album listing with detailed view modal, deletion functionality, and album/track statistics for administrators.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track

  import PremiereEcouteWeb.Admin.Pagination, only: [pagination_range: 2]

  @doc """
  Initializes admin albums page with paginated list and statistics.

  Loads first page of albums with default pagination, calculates album and track statistics, and initializes modal state for album details.
  """
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page, Album.page([], 1, 10))
    |> assign(:album_stats, album_stats())
    |> assign(:selected_album, nil)
    |> assign(:show_modal, false)
    |> then(fn socket -> {:ok, socket} end)
  end

  @doc """
  Updates pagination based on URL parameters.

  Parses page number and page size from URL parameters and reloads album list with requested pagination settings.
  """
  @impl true
  def handle_params(params, _url, socket) do
    page_number = String.to_integer(params["page"] || "1")
    page_size = String.to_integer(params["per_page"] || "10")

    socket
    |> assign(:page, Album.page([], page_number, page_size))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @doc """
  Handles album management events for modal display and deletion.

  Opens detail modal for selected album, closes modal, or deletes album with list refresh and appropriate flash messages.
  """
  @impl true
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

  defp album_stats do
    %{
      total_albums: Album.count(:id),
      total_tracks: Track.count(:id)
    }
  end
end
