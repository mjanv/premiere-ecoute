defmodule PremiereEcouteWeb.Admin.AdminSessionsLive do
  @moduledoc false

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Sessions.ListeningSession

  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Admin Sessions")
    |> assign(:page, ListeningSession.page([], 1, 2))
    |> assign(:selected_session, nil)
    |> assign(:show_modal, false)
    |> then(fn socket -> {:ok, socket} end)
  end

  def handle_params(params, _url, socket) do
    # AIDEV-NOTE: Handle pagination parameters from URL
    page_number = String.to_integer(params["page"] || "1")
    page_size = String.to_integer(params["per_page"] || "2")

    socket
    |> assign(:page, ListeningSession.page([], page_number, page_size))
    |> then(fn socket -> {:noreply, socket} end)
  end

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
    current_page = socket.assigns.page

    session_id
    |> ListeningSession.get()
    |> ListeningSession.delete()
    |> case do
      :ok ->
        socket
        |> assign(:page, ListeningSession.page([], current_page.page_number, current_page.page_size))
        |> put_flash(:info, gettext("Session deleted successfully"))

      :error ->
        socket
        |> put_flash(:error, gettext("Failed to delete session"))
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  defp format_datetime(datetime) when is_struct(datetime, DateTime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  defp format_datetime(_), do: "--"

  defp format_duration(started_at, ended_at) when is_struct(started_at, DateTime) and is_struct(ended_at, DateTime) do
    diff = DateTime.diff(ended_at, started_at, :second)
    minutes = div(diff, 60)
    seconds = rem(diff, 60)
    "#{minutes}m #{seconds}s"
  end

  defp format_duration(_, _), do: "--"

  defp status_class(:preparing), do: "bg-yellow-100 text-yellow-800"
  defp status_class(:active), do: "bg-green-100 text-green-800"
  defp status_class(:stopped), do: "bg-gray-100 text-gray-800"
  defp status_class(_), do: "bg-gray-100 text-gray-800"

  defp status_text(:preparing), do: "Preparing"
  defp status_text(:active), do: "Active"
  defp status_text(:stopped), do: "Stopped"
  defp status_text(_), do: "Unknown"

  # AIDEV-NOTE: Generate pagination range with ellipsis for lean display
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
