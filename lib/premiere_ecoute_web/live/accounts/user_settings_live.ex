defmodule PremiereEcouteWeb.Accounts.UserSettingsLive do
  use PremiereEcouteWeb, :live_view

  on_mount {PremiereEcouteWeb.UserAuth, :sudo_mode}

  alias PremiereEcoute.Accounts

  def mount(%{"token" => token}, _session, socket) do
    socket.assigns.current_scope.user
    |> Accounts.update_user_email(token)
    |> case do
      :ok -> put_flash(socket, :info, "Email changed successfully.")
      :error -> put_flash(socket, :error, "Email change link is invalid or it has expired.")
    end
    |> then(fn socket -> {:ok, push_navigate(socket, to: ~p"/users/settings")} end)
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    socket
    |> assign(:current_email, user.email)
    |> assign(
      :email_form,
      to_form(Accounts.User.email_changeset(user, %{}, validate_email: false))
    )
    |> assign(
      :password_form,
      to_form(Accounts.User.password_changeset(user, %{}, hash_password: false))
    )
    |> assign(:trigger_submit, false)
    |> then(fn socket -> {:ok, socket} end)
  end

  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.User.email_changeset(user_params, validate_email: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.User.email_changeset(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, put_flash(socket, :info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
