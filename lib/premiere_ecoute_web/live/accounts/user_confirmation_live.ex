defmodule PremiereEcouteWeb.Accounts.UserConfirmationLive do
  @moduledoc """
  Magic link authentication confirmation LiveView.

  Validates magic link tokens for passwordless authentication, handling token verification and automatic login submission with token expiration checks.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts

  @doc """
  Validates magic link token and initializes confirmation page.

  Verifies magic link token validity, retrieves associated user, prepares auto-submit form, or redirects to login with error if token is invalid or expired.
  """
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false), temporary_assigns: [form: nil]}
    else
      socket
      |> put_flash(:error, "Magic link is invalid or it has expired.")
      |> push_navigate(to: ~p"/users/log-in")
      |> then(fn socket -> {:ok, socket} end)
    end
  end

  @doc """
  Handles form submission with magic link token.

  Triggers automatic form submission to complete passwordless authentication flow and log user in.
  """
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
