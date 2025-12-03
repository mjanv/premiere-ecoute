defmodule PremiereEcouteWeb.Twitch.History.MessagesLive do
  @moduledoc """
  Displays detailed chat messages data from a Twitch history export.
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
