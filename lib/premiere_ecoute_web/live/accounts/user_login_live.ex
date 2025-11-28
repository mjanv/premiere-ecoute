defmodule PremiereEcouteWeb.Accounts.UserLoginLive do
  @moduledoc """
  User login LiveView with dual authentication methods.

  Provides password-based and magic link passwordless authentication, with email pre-filling, magic link delivery via email, and form submission handling for both login methods.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts

  @doc """
  Initializes login page with dual authentication options.

  Pre-fills email from flash or current user session, initializes login form for both password-based and magic link authentication methods.
  """
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @doc """
  Handles login form submissions for password and magic link authentication.

  Triggers password form submission for traditional login, or sends magic link email for passwordless authentication with user enumeration protection.
  """
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end
end
