defmodule PremiereEcouteWeb.Accounts.AccountLive do
  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts

  @impl true
  def mount(_params, _session, socket) do
    # AIDEV-NOTE: Get current user from authentication scope
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:page_title, "Account Settings")
      |> assign(:current_user, current_user)
      # In this app, Twitch user is the main user
      |> assign(:twitch_user, current_user)
      |> assign(:sessions_count, 0)

    {:ok, socket}
  end

  @impl true
  def handle_event("connect_spotify", _params, socket) do
    # AIDEV-NOTE: Redirect to Spotify OAuth flow
    {:noreply, redirect(socket, to: ~p"/auth/spotify")}
  end

  @impl true
  def handle_event("connect_twitch", _params, socket) do
    # AIDEV-NOTE: Redirect to Twitch OAuth flow
    {:noreply, redirect(socket, to: ~p"/auth/twitch")}
  end

  @impl true
  def handle_event("disconnect_spotify", _params, socket) do
    # AIDEV-NOTE: Disconnect Spotify by clearing tokens
    case socket.assigns.current_user do
      nil ->
        socket
        |> put_flash(:error, "User not found")

      user ->
        case Accounts.User.disconnect_spotify(user) do
          {:ok, user} ->
            socket
            |> assign(:current_user, user)
            |> put_flash(:info, "Spotify disconnected successfully")

          {:error, _changeset} ->
            socket
            |> put_flash(:error, "Failed to disconnect Spotify")
        end
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("disconnect_twitch", _params, socket) do
    # AIDEV-NOTE: Disconnect Twitch by clearing tokens (but keep user logged in)
    case socket.assigns.current_user do
      nil ->
        socket
        |> put_flash(:error, "User not found")

      user ->
        case Accounts.User.disconnect_twitch(user) do
          {:ok, user} ->
            socket
            |> assign(:current_user, user)
            |> put_flash(:info, "Twitch tokens revoked successfully")

          {:error, _changeset} ->
            socket
            |> put_flash(:error, "Failed to disconnect Twitch")
        end
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("delete_account", _params, socket) do
    {:noreply, socket}
  end
end
