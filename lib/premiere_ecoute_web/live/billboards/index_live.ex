defmodule PremiereEcouteWeb.Billboards.IndexLive do
  @moduledoc """
  LiveView for displaying all billboards created by a streamer.

  Shows billboards with their status, submission count, and action buttons.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Billboards

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket) do
    socket
    |> assign(:page_title, gettext("My Billboards"))
    |> assign(:billboards, Billboards.all(where: [user_id: user.id]))
    |> assign(:current_user, user)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_event("navigate", %{"billboard_id" => billboard_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/billboards/#{billboard_id}")}
  end

  # Helper functions

  defp billboard_status_badge(assigns) do
    class =
      case assigns.status do
        :created -> "bg-gray-600/20 text-gray-300 border-gray-500/30"
        :active -> "bg-green-600/20 text-green-300 border-green-500/30"
        :stopped -> "bg-red-600/20 text-red-300 border-red-500/30"
      end

    assigns = assign(assigns, :class, class)

    ~H"""
    <span class={"inline-flex items-center px-3 py-1 rounded-full text-xs font-medium border #{@class}"}>
      {String.capitalize(to_string(@status))}
    </span>
    """
  end

  defp format_date(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp format_date(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> format_date()
  end

  defp format_date(_), do: gettext("Unknown")
end
