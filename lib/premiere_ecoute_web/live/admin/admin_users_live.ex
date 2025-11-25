defmodule PremiereEcouteWeb.Admin.AdminUsersLive do
  @moduledoc """
  Admin users management LiveView.

  Provides user listing with detailed modal view, role management, account deletion functionality, and user role statistics for administrators.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User

  def mount(_params, _session, socket) do
    users = User.all()

    socket
    |> assign(:users, users)
    |> assign(:user_stats, user_stats(users))
    |> assign(:selected_user, nil)
    |> assign(:show_user_modal, false)
    |> then(fn socket -> {:ok, socket} end)
  end

  def handle_event("show_user_modal", %{"user_id" => user_id}, socket) do
    socket
    |> assign(:selected_user, User.get(user_id))
    |> assign(:show_user_modal, true)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("close_user_modal", _params, socket) do
    socket
    |> assign(:selected_user, nil)
    |> assign(:show_user_modal, false)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("modal_content_click", _params, socket), do: {:noreply, socket}

  def handle_event("change_role", %{"user_id" => user_id, "role" => role}, socket) do
    user_id
    |> User.get!()
    |> Accounts.update_user_role(String.to_existing_atom(role))
    |> case do
      {:ok, user} ->
        users = User.all()

        socket
        |> assign(:users, users)
        |> assign(:user_stats, user_stats(users))
        |> assign(:selected_user, user)
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("Failed to update user role"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  def handle_event("confirm_delete_user", %{"user_id" => user_id}, socket) do
    user = Accounts.User.get!(user_id)

    case Accounts.delete_account(%Scope{user: user}) do
      {:ok, _} ->
        users = Accounts.User.all()

        socket
        |> assign(:users, users)
        |> assign(:user_stats, user_stats(users))
        |> assign(:selected_user, nil)
        |> assign(:show_user_modal, false)
        |> put_flash(:info, gettext("User account has been deleted successfully"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _reason} ->
        socket
        |> put_flash(:error, gettext("Failed to delete user account"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  def user_stats(users) do
    users
    |> Enum.group_by(& &1.role)
    |> Enum.into(%{}, fn {role, users} -> {role, length(users)} end)
  end
end
