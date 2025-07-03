defmodule PremiereEcouteWeb.AccountLive do
  use PremiereEcouteWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # AIDEV-NOTE: Mock data for UI demonstration - replace with real data in future iterations
    socket =
      socket
      |> assign(:page_title, "Account Settings")
      # Will contain Twitch user data when connected
      |> assign(:twitch_user, nil)
      # Number of listening sessions created
      |> assign(:sessions_count, 0)

    {:ok, socket}
  end

  @impl true
  def handle_event("connect_spotify", _params, socket) do
    # AIDEV-NOTE: Empty handler as requested - no backend action
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_account", _params, socket) do
    # AIDEV-NOTE: Empty handler as requested - no backend action
    {:noreply, socket}
  end
end
