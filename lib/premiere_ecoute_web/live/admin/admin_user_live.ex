defmodule PremiereEcouteWeb.Admin.AdminUserLive do
  @moduledoc """
  Admin individual user management LiveView.

  Displays full user details with role management, impersonation, and deletion.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Repo

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = User.get!(id) |> Repo.preload([:twitch, :spotify])

    socket
    |> assign(:user, user)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_event("change_role", %{"role" => role}, socket) do
    socket.assigns.user
    |> Accounts.update_user_role(String.to_existing_atom(role))
    |> case do
      {:ok, user} ->
        socket
        |> assign(:user, Repo.preload(user, [:twitch, :spotify]))
        |> put_flash(:info, gettext("Role updated"))

      {:error, _} ->
        put_flash(socket, :error, gettext("Failed to update role"))
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("delete_user", _params, socket) do
    user = socket.assigns.user

    case Accounts.delete_account(%Scope{user: user}) do
      {:ok, _} ->
        socket
        |> put_flash(:info, gettext("User account deleted"))
        |> push_navigate(to: ~p"/admin/users")

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("Failed to delete user account"))
    end
    |> then(fn socket -> {:noreply, socket} end)
  end
end
