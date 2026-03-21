defmodule PremiereEcouteWeb.Admin.AdminUsersLive do
  @moduledoc """
  Admin users management LiveView.

  Provides paginated user listing with detailed modal view, role management, account deletion functionality, and user role statistics for administrators.
  """

  use PremiereEcouteWeb, :live_view

  import Ecto.Query

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Repo

  @doc """
  Initializes admin users page with paginated user list and role statistics.

  Loads first page of users with default pagination, calculates role distribution using a GROUP BY query, and initializes modal state for user detail viewing.
  """
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:search, "")
    |> assign(:role_filter, "")
    |> assign(:page, list_users("", "", 1, 10))
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
    |> assign(:page, list_users(socket.assigns.search, socket.assigns.role_filter, page_number, page_size))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("filter", %{"search" => search, "role" => role}, %{assigns: %{page: page}} = socket) do
    socket
    |> assign(:search, search)
    |> assign(:role_filter, role)
    |> assign(:page, list_users(search, role, 1, page.page_size))
    |> then(fn socket -> {:noreply, socket} end)
  end

  # AIDEV-NOTE: custom query for admin search/filter — User.page doesn't support dynamic text search
  defp list_users(search, role, page_number, page_size) do
    User
    |> then(fn q ->
      if search != "" do
        term = "%#{search}%"
        where(q, [u], ilike(u.email, ^term) or ilike(u.username, ^term))
      else
        q
      end
    end)
    |> then(fn q ->
      if role != "" do
        where(q, [u], u.role == ^String.to_existing_atom(role))
      else
        q
      end
    end)
    |> order_by(asc: :inserted_at)
    |> preload([:twitch, :spotify])
    |> Repo.paginate(page: page_number, page_size: page_size)
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
