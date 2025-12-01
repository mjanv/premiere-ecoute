defmodule PremiereEcouteWeb.PlaygroundLive do
  @moduledoc """
  Development playground LiveView.

  Provides a sandbox environment for testing and developing UI components and features.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Twitch.History.SiteHistory.MinuteWatched

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    data = "priv/request-1.zip" |> MinuteWatched.read() |> MinuteWatched.group_day()

    {:noreply, assign_async(socket, [:data], fn -> {:ok, %{data: data}} end)}
  end
end
