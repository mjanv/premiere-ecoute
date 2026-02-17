defmodule PremiereEcouteWeb.Accounts.AccountFeaturesLive do
  @moduledoc """
  Streamer/admin feature settings LiveView.

  Manages feature-specific settings (radio tracking) accessible only to streamers and admins.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.User.Profile

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

    not_allowed =
      is_nil(current_user) or
        current_user.role not in [:streamer, :admin] or
        not PremiereEcouteCore.FeatureFlag.enabled?(:radio, for: current_user)

    if not_allowed do
      {:ok, push_navigate(socket, to: ~p"/users/account")}
    else
      profile_form =
        current_user.profile
        |> Profile.changeset()
        |> to_form()

      {:ok, assign(socket, current_user: current_user, profile_form: profile_form)}
    end
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
    case Accounts.User.edit_user_profile(socket.assigns.current_user, profile_params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:profile_form, updated_user.profile |> Profile.changeset() |> to_form())
         |> put_flash(:info, "Settings saved")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:profile_form, to_form(changeset))
         |> put_flash(:error, "Failed to save settings")}
    end
  end
end
