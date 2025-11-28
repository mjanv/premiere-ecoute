defmodule PremiereEcouteWeb.Admin.AdminSessionsLive do
  @moduledoc """
  Admin listening sessions management LiveView.

  Provides paginated session listing with detailed modal view, deletion functionality with confirmation, session status tracking, and session/vote statistics for administrators.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Vote

  @doc """
  Initializes admin sessions page with paginated list and statistics.

  Loads first page of listening sessions with default pagination, calculates session status distribution and vote statistics, and initializes modal states for detail viewing and deletion confirmation.
  """
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    sessions = ListeningSession.all([])

    socket
    |> assign(:page, ListeningSession.page([], 1, 10))
    |> assign(:session_stats, session_stats(sessions))
    |> assign(:selected_session, nil)
    |> assign(:show_modal, false)
    |> assign(:show_delete_modal, false)
    |> assign(:session_to_delete, nil)
    |> then(fn socket -> {:ok, socket} end)
  end

  @doc """
  Updates pagination based on URL parameters.

  Parses page number and page size from URL parameters and reloads session list with requested pagination settings.
  """
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(params, _url, socket) do
    page_number = String.to_integer(params["page"] || "1")
    page_size = String.to_integer(params["per_page"] || "10")

    socket
    |> assign(:page, ListeningSession.page([], page_number, page_size))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @doc """
  Handles session management events for modal display and deletion.

  Opens detail modal for selected session, closes modals, initiates deletion with confirmation dialog, or confirms and executes session deletion with list refresh and appropriate flash messages.
  """
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("show_session_modal", %{"session_id" => session_id}, socket) do
    socket
    |> assign(:selected_session, ListeningSession.get(session_id))
    |> assign(:show_modal, true)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("close_modal", _params, socket) do
    socket
    |> assign(:selected_session, nil)
    |> assign(:show_modal, false)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("delete_session", %{"session_id" => session_id}, socket) do
    session = ListeningSession.get(session_id)

    socket
    |> assign(:session_to_delete, session)
    |> assign(:show_delete_modal, true)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("close_delete_modal", _params, socket) do
    socket
    |> assign(:session_to_delete, nil)
    |> assign(:show_delete_modal, false)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("confirm_delete_session", _params, socket) do
    current_page = socket.assigns.page
    session = socket.assigns.session_to_delete

    session
    |> ListeningSession.delete()
    |> case do
      {:ok, _deleted_session} ->
        socket
        |> assign(:page, ListeningSession.page([], current_page.page_number, current_page.page_size))
        |> assign(:session_to_delete, nil)
        |> assign(:show_delete_modal, false)
        |> put_flash(:info, gettext("Session deleted successfully"))

      {:error, _changeset} ->
        socket
        |> assign(:session_to_delete, nil)
        |> assign(:show_delete_modal, false)
        |> put_flash(:error, gettext("Failed to delete session"))
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  defp status_class(:preparing), do: "bg-yellow-100 text-yellow-800"
  defp status_class(:active), do: "bg-green-100 text-green-800"
  defp status_class(:stopped), do: "bg-gray-100 text-gray-800"
  defp status_class(_), do: "bg-gray-100 text-gray-800"

  defp status_text(:preparing), do: "Preparing"
  defp status_text(:active), do: "Active"
  defp status_text(:stopped), do: "Stopped"
  defp status_text(_), do: "Unknown"

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

  defp session_stats(sessions) do
    status_stats =
      sessions
      |> Enum.group_by(& &1.status)
      |> Enum.into(%{}, fn {status, sessions} -> {status, length(sessions)} end)

    total_votes = Vote.count(:id)

    Map.put(status_stats, :total_votes, total_votes)
  end
end
