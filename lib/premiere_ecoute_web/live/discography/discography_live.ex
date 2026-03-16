defmodule PremiereEcouteWeb.Discography.DiscographyLive do
  @moduledoc """
  Discography landing page — three sections (Artists, Albums, Singles) with the 5 most
  recently added entries each, plus a "More" link to the dedicated catalog page.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Single

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:last_albums, Discography.last_albums())
     |> assign(:last_singles, Discography.last_singles())
     |> assign(:last_artists, Discography.last_artists(10))
     |> assign(:album_count, Album.count(Album, :id))
     |> assign(:single_count, Single.count(Single, :id))
     |> assign(:artist_count, Artist.count(Artist, :id))}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}
end
