defmodule PremiereEcouteWeb.PlaygroundLive do
  @moduledoc false

  use PremiereEcouteWeb, :live_view

  import PremiereEcouteWeb.Components.Modal

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
