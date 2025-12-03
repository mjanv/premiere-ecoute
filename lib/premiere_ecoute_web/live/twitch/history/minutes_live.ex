defmodule PremiereEcouteWeb.Twitch.History.MinutesLive do
  @moduledoc """
  Displays detailed minutes watched data from a Twitch history export.
  """

  use PremiereEcouteWeb, :live_view

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:filename, id)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
