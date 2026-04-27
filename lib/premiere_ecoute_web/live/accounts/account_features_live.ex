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

      {:ok,
       socket
       |> assign(current_user: current_user, profile_form: profile_form)
       |> assign(:api_tokens, Accounts.list_user_api_tokens(current_user))
       |> assign(:new_api_token, nil)
       |> assign(:overlay_score_type, "streamer")}
    end
  end

  @impl true
  def handle_event("change_overlay_score_type", %{"score_type" => score_type}, socket) do
    {:noreply, assign(socket, :overlay_score_type, score_type)}
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
        socket
        |> assign(:current_user, updated_user)
        |> assign(:profile_form, updated_user.profile |> Profile.changeset() |> to_form())
        |> put_flash(:info, "Settings saved")
        |> then(fn socket -> {:noreply, socket} end)

      {:error, changeset} ->
        socket
        |> assign(:profile_form, to_form(changeset))
        |> put_flash(:error, "Failed to save settings")
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  @impl true
  def handle_event("generate_api_token", _params, socket) do
    token = Accounts.generate_user_api_token(socket.assigns.current_user)
    tokens = Accounts.list_user_api_tokens(socket.assigns.current_user)

    socket
    |> assign(:api_tokens, tokens)
    |> assign(:new_api_token, token)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("revoke_api_tokens", _params, socket) do
    Accounts.delete_user_api_tokens(socket.assigns.current_user)

    socket
    |> assign(:api_tokens, [])
    |> assign(:new_api_token, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  defp overlay_url(username, "collections") do
    "#{PremiereEcouteWeb.Endpoint.url()}/collections/overlay/#{username}"
  end

  defp overlay_url(username, score_type) do
    "#{PremiereEcouteWeb.Endpoint.url()}/sessions/overlay/#{username}?score=#{score_type}"
  end

  defp obs_size_hint("streamer"), do: "300 × 300"
  defp obs_size_hint("viewer"), do: "300 × 300"
  defp obs_size_hint("both"), do: "600 × 300"
  defp obs_size_hint("player"), do: "1200 × 240"
  defp obs_size_hint("votes"), do: "800 × 240"
  defp obs_size_hint("collections"), do: "800 × 600"
  defp obs_size_hint(_), do: "300 × 300"
end
