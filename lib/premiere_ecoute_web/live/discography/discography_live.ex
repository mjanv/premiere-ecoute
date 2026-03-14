defmodule PremiereEcouteWeb.Discography.DiscographyLive do
  @moduledoc """
  Discography landing page — links to albums, singles, and artists.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Single

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:album_count, Album.count(Album, :id))
     |> assign(:single_count, Single.count(Single, :id))
     |> assign(:artist_count, Artist.count(Artist, :id))}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}
end
