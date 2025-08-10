defmodule PremiereEcouteWeb.Retrospective.HistoryLive do
  @moduledoc """
  LiveView for the streamer dashboard showing albums listened in time periods as a cover wall.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Sessions

  @impl true
  def mount(_params, _session, socket) do
    current_date = DateTime.utc_now()

    socket =
      socket
      |> assign(:current_user, socket.assigns.current_scope.user)
      |> assign(:selected_period, :month)
      |> assign(:selected_year, current_date.year)
      |> assign(:selected_month, current_date.month)
      |> assign(:years_available, get_available_years())
      |> assign(:show_modal, false)
      |> assign(:modal_session_id, nil)

    user_id = socket.assigns.current_user.id
    period = :month
    year = current_date.year
    month = current_date.month

    socket
    |> assign_async(:albums_data, fn ->
      albums = Sessions.get_albums_by_period(user_id, period, %{year: year, month: month})
      {:ok, %{albums_data: albums}}
    end)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(params, _url, socket) do
    period =
      case params["period"] do
        "month" -> :month
        "year" -> :year
        _ -> socket.assigns.selected_period
      end

    year = parse_year(params["year"]) || socket.assigns.selected_year
    month = parse_month(params["month"]) || socket.assigns.selected_month

    socket = assign(socket, :selected_period, period)
    socket = assign(socket, :selected_year, year)
    socket = assign(socket, :selected_month, month)

    user_id = socket.assigns.current_user.id

    socket
    |> assign_async(:albums_data, fn ->
      albums = Sessions.get_albums_by_period(user_id, period, %{year: year, month: month})
      {:ok, %{albums_data: albums}}
    end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("change_period", %{"period" => period_str, "year" => year_str, "month" => month_str}, socket) do
    period = String.to_existing_atom(period_str)
    {year, ""} = Integer.parse(year_str)
    {month, ""} = Integer.parse(month_str)

    # Build new URL with updated parameters
    url_params = build_params(period, year, month)
    {:noreply, push_patch(socket, to: ~p"/retrospective/history?#{url_params}")}
  end

  @impl true
  def handle_event("show_album_details", %{"session_id" => session_id}, socket) do
    socket
    |> assign(:show_modal, true)
    |> assign(:modal_session_id, session_id)
    |> assign_async(:modal_data, fn -> load_modal_data(session_id) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    socket
    |> assign(:show_modal, false)
    |> assign(:modal_session_id, nil)
    |> assign(:modal_data, %{loading: false, ok?: false, result: nil})
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("navigate", %{"direction" => direction}, socket) do
    current_date = Date.new!(socket.assigns.selected_year, socket.assigns.selected_month, 1)

    new_date =
      case {direction, socket.assigns.selected_period} do
        {"previous", :month} -> Date.add(current_date, -Date.days_in_month(current_date))
        {"next", :month} -> Date.add(current_date, Date.days_in_month(current_date))
        {"previous", :year} -> Date.add(current_date, -365)
        {"next", :year} -> Date.add(current_date, 365)
      end

    params = build_params(socket.assigns.selected_period, new_date.year, new_date.month)
    {:noreply, push_patch(socket, to: ~p"/retrospective/history?#{params}")}
  end

  @impl true
  def handle_event("toggle_period", _params, socket) do
    new_period = if socket.assigns.selected_period == :month, do: :year, else: :month

    params = build_params(new_period, socket.assigns.selected_year, socket.assigns.selected_month)
    {:noreply, push_patch(socket, to: ~p"/retrospective/history?#{params}")}
  end

  # Private helper functions

  defp load_modal_data(session_id) do
    case Sessions.get_album_session_details(session_id) do
      {:ok, details} ->
        {:ok, %{modal_data: details}}

      {:error, :not_found} ->
        {:ok, %{modal_data: nil}}
    end
  end

  defp parse_year(year_str) when is_binary(year_str) do
    case Date.from_iso8601("#{year_str}-01-01") do
      {:ok, %Date{year: year}} when year >= 2020 and year <= 2030 -> year
      _ -> nil
    end
  end

  defp parse_year(_), do: nil

  defp parse_month(month_str) when is_binary(month_str) do
    case Date.from_iso8601("2024-#{String.pad_leading(month_str, 2, "0")}-01") do
      {:ok, %Date{month: month}} when month >= 1 and month <= 12 -> month
      _ -> nil
    end
  end

  defp parse_month(_), do: nil

  defp build_params(period, year, month) do
    params = %{"period" => Atom.to_string(period), "year" => Integer.to_string(year)}

    if period == :month do
      Map.put(params, "month", Integer.to_string(month))
    else
      params
    end
  end

  defp get_available_years do
    # Generate years from 2020 to current year + 1
    current_year = DateTime.utc_now().year
    2020..current_year |> Enum.to_list() |> Enum.reverse()
  end
end
