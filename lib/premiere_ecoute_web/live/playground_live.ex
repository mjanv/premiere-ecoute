defmodule PremiereEcouteWeb.PlaygroundLive do
  @moduledoc """
  Development playground LiveView.

  Provides a sandbox environment for testing and developing UI components and features.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcouteWeb.Components.Drawer

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket}

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}
end
