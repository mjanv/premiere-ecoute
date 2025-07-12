defmodule PremiereEcouteWeb.Admin.AdminUsersLive do
  @moduledoc false

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Repo

  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Admin Users")
    |> assign(:users, User.all())
    |> assign(:selected_user, nil)
    |> assign(:show_user_modal, false)
    |> then(fn socket -> {:ok, socket} end)
  end

  def handle_event("show_user_modal", %{"user_id" => user_id}, socket) do
    user = User.get!(user_id)

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

  def handle_event("toggle_role", %{"user_id" => user_id}, socket) do
    user = User.get!(user_id)
    new_role = if user.role == :admin, do: :streamer, else: :admin

    user
    |> Ecto.Changeset.cast(%{role: new_role}, [:role])
    |> Ecto.Changeset.validate_inclusion(:role, [:streamer, :admin])
    |> Repo.update()
    |> case do
      {:ok, updated_user} ->
        socket
        |> assign(:users, User.all())
        |> assign(:selected_user, updated_user)
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("Failed to update user role"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end
end
