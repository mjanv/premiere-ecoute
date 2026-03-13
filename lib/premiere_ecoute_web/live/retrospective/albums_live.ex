defmodule PremiereEcouteWeb.Retrospective.AlbumsLive do
  @moduledoc """
  Album catalog page — lists all albums with their cover, artist, and review count.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography
  alias PremiereEcoute.Sessions.Reviews

  @impl true
  def mount(_params, _session, socket) do
    albums = Discography.list_albums()
    review_counts = Reviews.count_by_album(Enum.map(albums, & &1.id))

    {:ok,
     socket
     |> assign(:albums, albums)
     |> assign(:review_counts, review_counts)}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}
end
