defmodule PremiereEcouteWeb.Admin.AdminUsersLive do
  @moduledoc false

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts

  def mount(_params, _session, socket) do
    users = Accounts.User.all()
    # AIDEV-NOTE: Calculate user statistics by role for admin dashboard
    user_stats =
      users
      |> Enum.group_by(& &1.role)
      |> Enum.into(%{}, fn {role, users} -> {role, length(users)} end)

    socket
    |> assign(:users, users)
    |> assign(:user_stats, user_stats)
    |> assign(:selected_user, nil)
    |> assign(:show_user_modal, false)
    |> then(fn socket -> {:ok, socket} end)
  end

  def handle_event("show_user_modal", %{"user_id" => user_id}, socket) do
    user = Accounts.User.get!(user_id)

    socket
    |> assign(:selected_user, user)
    |> assign(:show_user_modal, true)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("close_user_modal", _params, socket) do
    socket
    |> assign(:selected_user, nil)
    |> assign(:show_user_modal, false)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("modal_content_click", _params, socket) do
    # Do nothing - this prevents the modal from closing when clicking inside
    {:noreply, socket}
  end

  def handle_event("change_role", %{"user_id" => user_id, "role" => role}, socket) do
    user_id
    |> Accounts.User.get!()
    |> Accounts.update_user_role(String.to_atom(role))
    |> case do
      {:ok, user} ->
        users = Accounts.User.all()
        # AIDEV-NOTE: Recalculate user statistics after role change
        user_stats =
          users
          |> Enum.group_by(& &1.role)
          |> Enum.into(%{}, fn {role, users} -> {role, length(users)} end)

        socket
        |> assign(:users, users)
        |> assign(:user_stats, user_stats)
        |> assign(:selected_user, user)
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("Failed to update user role"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end
end
