defmodule PremiereEcouteWeb.Accounts.AccountLive do
  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Services.AccountCompliance

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

    socket
    |> assign(:current_user, current_user)
    |> assign(:show_download_modal, false)
    |> assign(:show_delete_modal, false)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, assign(socket, :current_path, URI.parse(url).path || "/")}
  end

  @impl true
  def handle_event("connect_spotify", _params, socket) do
    {:noreply, redirect(socket, to: ~p"/auth/spotify")}
  end

  @impl true
  def handle_event("connect_twitch", _params, socket) do
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
  def handle_event("show_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, true)}
  end

  @impl true
  def handle_event("hide_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, false)}
  end

  @impl true
  def handle_event("confirm_delete_account", _params, socket) do
    # AIDEV-NOTE: Account deletion with automatic logout
    case socket.assigns.current_scope do
      nil ->
        socket
        |> put_flash(:error, "User not found")
        |> assign(:show_delete_modal, false)

      scope ->
        case Accounts.delete_account(scope) do
          {:ok, _deleted_user} ->
            # AIDEV-NOTE: User tokens are already deleted by delete_account function
            # Redirect to homepage where authentication will be handled naturally
            socket
            |> put_flash(:info, "Your account has been permanently deleted. You have been logged out.")
            |> assign(:show_delete_modal, false)
            |> redirect(to: ~p"/")

          {:error, _reason} ->
            socket
            |> put_flash(:error, "Failed to delete account. Please try again.")
            |> assign(:show_delete_modal, false)
        end
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("show_download_modal", _params, socket) do
    {:noreply, assign(socket, :show_download_modal, true)}
  end

  @impl true
  def handle_event("hide_download_modal", _params, socket) do
    {:noreply, assign(socket, :show_download_modal, false)}
  end

  @impl true
  def handle_event("stop_propagation", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("download_data", _params, socket) do
    # AIDEV-NOTE: GDPR data download implementation
    case socket.assigns.current_scope do
      nil ->
        socket
        |> put_flash(:error, "User not found")
        |> assign(:show_download_modal, false)

      scope ->
        case AccountCompliance.download_associated_data(scope) do
          {:ok, json_data} ->
            filename = "premiere_ecoute_data_#{scope.user.id}_#{Date.utc_today()}.json"

            socket
            |> push_event("download_file", %{
              data: json_data,
              filename: filename,
              content_type: "application/json"
            })
            |> assign(:show_download_modal, false)
            |> put_flash(:info, "Data download started")

          {:error, reason} ->
            socket
            |> put_flash(:error, "Failed to generate data export: #{inspect(reason)}")
            |> assign(:show_download_modal, false)
        end
    end
    |> then(fn socket -> {:noreply, socket} end)
  end
end
