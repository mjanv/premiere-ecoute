defmodule PremiereEcouteWeb.Accounts.UserConfirmationLive do
  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts

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

  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
