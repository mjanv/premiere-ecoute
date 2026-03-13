defmodule PremiereEcouteWeb.Discography.SinglesLive do
  @moduledoc """
  Singles catalog page — lists all singles with their cover, artist, and name.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :singles, Discography.list_singles())}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}
end
