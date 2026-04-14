defmodule PremiereEcouteWeb.Admin.AdminArtistsLive do
  @moduledoc """
  Admin artists management LiveView.

  Provides paginated artist listing with statistics for administrators.
  """

  use PremiereEcouteWeb, :live_view

  import PremiereEcouteWeb.Admin.Pagination, only: [pagination_range: 2]

  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Workers.EnrichArtistWorker
  alias PremiereEcoute.Discography.Workers.EnrichDiscographyWorker
  alias PremiereEcoute.PubSub

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:search, "")
    |> assign(:page, Artist.page([], 1, 20))
    |> assign(:artist_stats, artist_stats())
    |> assign(:selected_artist, nil)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(params, _url, socket) do
    page_number = String.to_integer(params["page"] || "1")
    page_size = String.to_integer(params["per_page"] || "20")
    search = socket.assigns.search

    socket
    |> assign(
      :page,
      if(search == "", do: Artist.page([], page_number, page_size), else: Artist.search([:name], search, page_number, page_size))
    )
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
    |> assign(
      :page,
      if(search == "", do: Artist.page([], 1, page.page_size), else: Artist.search([:name], search, 1, page.page_size))
    )
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("enrich_artist", %{"id" => id}, socket) do
    case EnrichArtistWorker.now(%{"id" => id}) do
      {:ok, _} -> put_flash(socket, :info, gettext("Enrichment job started"))
      {:error, _} -> put_flash(socket, :error, gettext("Failed to start enrichment"))
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("enrich_discography", %{"id" => id}, socket) do
    case EnrichDiscographyWorker.now(%{"id" => id}) do
      {:ok, _} -> put_flash(socket, :info, gettext("Enrichment job started"))
      {:error, _} -> put_flash(socket, :error, gettext("Failed to start enrichment"))
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:artist_enriched, artist}, %{assigns: %{page: page, search: search}} = socket) do
    socket
    |> assign(:selected_artist, artist)
    |> assign(
      :page,
      if(search == "",
        do: Artist.page([], page.page_number, page.page_size),
        else: Artist.search([:name], search, page.page_number, page.page_size)
      )
    )
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp artist_stats do
    %{total_artists: Artist.count(:id), enriched_artists: Artist.count_enriched()}
  end
end
