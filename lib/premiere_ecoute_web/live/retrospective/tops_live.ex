defmodule PremiereEcouteWeb.Retrospective.TopsLive do
  @moduledoc """
  LiveView for displaying a viewer's top-voted tracks sorted by vote score.
  Supports three period modes: all-time, year, and month.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Sessions

  import PremiereEcouteWeb.Retrospective.PeriodHelpers

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns.current_scope.user.twitch do
      nil ->
        socket
        |> put_flash(:error, "Connect to Twitch")
        |> push_navigate(to: ~p"/home")
        |> then(fn socket -> {:ok, socket} end)

      _ ->
        current_date = DateTime.utc_now()

        socket =
          socket
          |> assign(:current_user, socket.assigns.current_scope.user)
          |> assign(:selected_period, :all)
          |> assign(:selected_year, current_date.year)
          |> assign(:selected_month, current_date.month)
          |> assign(:years_available, get_available_years())

        {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    period =
      case params["period"] do
        "all" -> :all
        "month" -> :month
        "year" -> :year
        _ -> socket.assigns.selected_period
      end

    year = parse_year(params["year"]) || socket.assigns.selected_year
    month = parse_month(params["month"]) || socket.assigns.selected_month

    socket =
      socket
      |> assign(:selected_period, period)
      |> assign(:selected_year, year)
      |> assign(:selected_month, month)

    user = socket.assigns.current_user

    socket
    |> assign_async(:tops_data, fn ->
      tracks = Sessions.get_top_tracks_by_period(user, period, %{year: year, month: month})
      {:ok, %{tops_data: tracks}}
    end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("navigate", %{"direction" => direction}, socket) do
    current_date = Date.new!(socket.assigns.selected_year, socket.assigns.selected_month, 1)

    new_date =
      case {direction, socket.assigns.selected_period} do
        {"previous", :month} -> Date.shift(current_date, month: -1)
        {"next", :month} -> Date.shift(current_date, month: 1)
        {"previous", :year} -> Date.shift(current_date, year: -1)
        {"next", :year} -> Date.shift(current_date, year: 1)
        _ -> current_date
      end

    params = build_params(socket.assigns.selected_period, new_date.year, new_date.month)
    {:noreply, push_patch(socket, to: ~p"/retrospective/tops?#{params}")}
  end

  @impl true
  def handle_event("set_period", %{"period" => period_str}, socket) do
    period = String.to_existing_atom(period_str)
    params = build_params(period, socket.assigns.selected_year, socket.assigns.selected_month)
    {:noreply, push_patch(socket, to: ~p"/retrospective/tops?#{params}")}
  end
end
