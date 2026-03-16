defmodule PremiereEcouteWeb.Discography.ArtistsLive do
  @moduledoc """
  Artists catalog page — lists all artists in the discography.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography
  alias PremiereEcoute.Discography.Artist

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :artists, Discography.list_artists())}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}
end
