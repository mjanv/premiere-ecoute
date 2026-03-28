defmodule PremiereEcouteWeb.Admin.AdminArtistsLive do
  @moduledoc """
  Admin artists management LiveView.

  Provides paginated artist listing with statistics for administrators.
  """

  use PremiereEcouteWeb, :live_view

  import Ecto.Query
  import PremiereEcouteWeb.Admin.Pagination, only: [pagination_range: 2]

  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Workers.EnrichArtistWorker
  alias PremiereEcoute.PubSub
  alias PremiereEcoute.Repo

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:search, "")
    |> assign(:page, list_artists("", 1, 20))
    |> assign(:artists_count, Artist.count(:id))
    |> assign(:selected_artist, nil)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(params, _url, socket) do
    page_number = String.to_integer(params["page"] || "1")
    page_size = String.to_integer(params["per_page"] || "20")

    socket
    |> assign(:page, list_artists(socket.assigns.search, page_number, page_size))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("show_artist", %{"id" => id}, socket) do
    artist = Artist.get(id)
    PubSub.subscribe("artist:#{artist.id}")
    {:noreply, assign(socket, :selected_artist, artist)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :selected_artist, nil)}
  end

  def handle_event("search", %{"search" => search}, %{assigns: %{page: page}} = socket) do
    socket
    |> assign(:search, search)
    |> assign(:page, list_artists(search, 1, page.page_size))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("enrich_artist", %{"slug" => slug}, socket) do
    case EnrichArtistWorker.now(%{"slug" => slug}) do
      {:ok, _} -> put_flash(socket, :info, gettext("Enrichment job started"))
      {:error, _} -> put_flash(socket, :error, gettext("Failed to start enrichment"))
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:artist_enriched, artist}, %{assigns: %{page: page, search: search}} = socket) do
    socket
    |> assign(:selected_artist, artist)
    |> assign(:page, list_artists(search, page.page_number, page.page_size))
    |> then(fn socket -> {:noreply, socket} end)
  end

  defp list_artists(search, page_number, page_size) do
    Artist
    |> then(fn q ->
      if search != "" do
        term = "%#{search}%"
        where(q, [a], ilike(a.name, ^term))
      else
        q
      end
    end)
    |> order_by(asc: :name)
    |> Repo.paginate(page: page_number, page_size: page_size)
  end
end
