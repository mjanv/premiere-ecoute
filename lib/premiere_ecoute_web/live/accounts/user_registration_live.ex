defmodule PremiereEcouteWeb.Accounts.UserRegistrationLive do
  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.User

  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket) when not is_nil(user) do
    {:ok, redirect(socket, to: PremiereEcouteWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    {:ok, assign_form(socket, Accounts.User.email_changeset(%User{})), temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.User.create(user_params) do
      {:ok, user} ->
        {:ok, _} = Accounts.deliver_login_instructions(user, &url(~p"/users/log-in/#{&1}"))

        socket
        |> put_flash(:info, "An email was sent to #{user.email}, please access it to confirm your account.")
        |> push_navigate(to: ~p"/users/log-in")
        |> then(fn socket -> {:noreply, socket} end)

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.User.email_changeset(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "user"))
  end
end
