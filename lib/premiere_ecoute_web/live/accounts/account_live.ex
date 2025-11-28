defmodule PremiereEcouteWeb.Accounts.AccountLive do
  @moduledoc """
  User account management and profile settings LiveView.

  Manages user profile editing with theme and language preferences, OAuth provider connections (Spotify/Twitch), account data export for GDPR compliance, and account deletion with confirmation modals.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Services.AccountCompliance
  alias PremiereEcoute.Accounts.User.Profile

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

    profile_form =
      if current_user do
        current_user.profile
        |> Profile.changeset()
        |> to_form()
      else
        nil
      end

    socket
    |> assign(:current_user, current_user)
    |> assign(:show_download_modal, false)
    |> assign(:show_delete_modal, false)
    |> assign(:profile_form, profile_form)
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
    case socket.assigns.current_user do
      nil ->
        socket
        |> put_flash(:error, "User not found")

      user ->
        {:ok, user} = Accounts.User.disconnect_provider(user, :spotify)

        socket
        |> assign(:current_user, user)
        |> put_flash(:info, "Spotify disconnected successfully")
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("disconnect_twitch", _params, socket) do
    case socket.assigns.current_user do
      nil ->
        socket
        |> put_flash(:error, "User not found")

      user ->
        {:ok, user} = Accounts.User.disconnect_provider(user, :twitch)

        socket
        |> assign(:current_user, user)
        |> put_flash(:info, "Twitch tokens revoked successfully")
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
    case socket.assigns.current_scope do
      nil ->
        socket
        |> put_flash(:error, "User not found")
        |> assign(:show_delete_modal, false)

      scope ->
        case Accounts.delete_account(scope) do
          {:ok, _deleted_user} ->
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
  def handle_event("validate_profile", %{"profile" => profile_params}, socket) do
    profile_form =
      socket.assigns.current_user.profile
      |> Profile.changeset(profile_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :profile_form, profile_form)}
  end

  @impl true
  def handle_event("save_profile", %{"profile" => profile_params}, socket) do
    case socket.assigns.current_user do
      nil ->
        socket
        |> put_flash(:error, "User not found")

      user ->
        case Accounts.User.edit_user_profile(user, profile_params) do
          {:ok, updated_user} ->
            updated_profile_form =
              updated_user.profile
              |> Profile.changeset()
              |> to_form()

            # Push theme update to client when color scheme changes
            theme =
              case updated_user.profile.color_scheme do
                :light -> "light"
                :dark -> "dark"
                :system -> "system"
              end

            # Update locale immediately when language changes
            locale = Atom.to_string(updated_user.profile.language)
            Gettext.put_locale(PremiereEcoute.Gettext, locale)

            socket
            |> assign(:current_user, updated_user)
            |> assign(:profile_form, updated_profile_form)
            |> push_event("phx:set-theme", %{theme: theme})
            |> push_navigate(to: ~p"/users/account")
            |> put_flash(:info, "Profile updated successfully")

          {:error, changeset} ->
            profile_form = changeset |> to_form()

            socket
            |> assign(:profile_form, profile_form)
            |> put_flash(:error, "Failed to update profile")
        end
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("download_data", _params, socket) do
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
