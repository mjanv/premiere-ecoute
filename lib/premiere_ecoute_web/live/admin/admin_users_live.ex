defmodule PremiereEcouteWeb.Admin.AdminUsersLive do
  @moduledoc """
  Admin users management LiveView.

  Provides paginated user listing with detailed modal view, role management, account deletion functionality, and user role statistics for administrators.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User

  @doc """
  Initializes admin users page with paginated user list and role statistics.

  Loads first page of users with default pagination, calculates role distribution using a GROUP BY query, and initializes modal state for user detail viewing.
  """
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page, User.page([], 1, 10))
    |> assign(:user_stats, User.count_by_role())
    |> assign(:selected_user, nil)
    |> assign(:show_user_modal, false)
    |> then(fn socket -> {:ok, socket} end)
  end

  @doc """
  Updates pagination based on URL parameters.

  Parses page number and page size from URL parameters and reloads user list with requested pagination settings.
  """
  @impl true
  def handle_params(params, _url, socket) do
    page_number = String.to_integer(params["page"] || "1")
    page_size = String.to_integer(params["per_page"] || "10")

    socket
    |> assign(:page, User.page([], page_number, page_size))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @doc """
  Handles user management events for modal display, role changes, and deletion.

  Opens or closes user detail modal, updates user roles with list refresh, or deletes user accounts with appropriate confirmation and error handling.
  """
  @impl true
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
        current_page = socket.assigns.page

        socket
        |> assign(:page, User.page([], current_page.page_number, current_page.page_size))
        |> assign(:user_stats, User.count_by_role())
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
        current_page = socket.assigns.page

        socket
        |> assign(:page, User.page([], current_page.page_number, current_page.page_size))
        |> assign(:user_stats, User.count_by_role())
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

  defp pagination_range(current_page, total_pages) do
    cond do
      total_pages <= 7 ->
        1..total_pages |> Enum.to_list()

      current_page <= 4 ->
        [1, 2, 3, 4, 5, :ellipsis, total_pages]

      current_page >= total_pages - 3 ->
        [1, :ellipsis, total_pages - 4, total_pages - 3, total_pages - 2, total_pages - 1, total_pages]

      true ->
        [1, :ellipsis, current_page - 1, current_page, current_page + 1, :ellipsis, total_pages]
    end
  end
end
