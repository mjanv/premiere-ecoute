defmodule PremiereEcouteWeb.Admin.AdminUsersLive do
  @moduledoc """
  Admin users management LiveView.

  Provides paginated user listing with detailed modal view, role management, account deletion functionality, and user role statistics for administrators.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts.User

  @doc """
  Initializes admin users page with paginated user list and role statistics.

  Loads first page of users with default pagination, calculates role distribution using a GROUP BY query, and initializes modal state for user detail viewing.
  """
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:search, "")
    |> assign(:role_filter, "")
    |> assign(:page, User.list_for_admin("", "", 1, 10))
    |> assign(:user_stats, User.count_by_role())
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
    |> assign(:page, User.list_for_admin(socket.assigns.search, socket.assigns.role_filter, page_number, page_size))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("filter", %{"search" => search, "role" => role}, %{assigns: %{page: page}} = socket) do
    socket
    |> assign(:search, search)
    |> assign(:role_filter, role)
    |> assign(:page, User.list_for_admin(search, role, 1, page.page_size))
    |> then(fn socket -> {:noreply, socket} end)
  end

  import PremiereEcouteWeb.Admin.Pagination, only: [pagination_range: 2]
end
