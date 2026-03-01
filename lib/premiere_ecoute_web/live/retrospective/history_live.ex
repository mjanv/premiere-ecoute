defmodule PremiereEcouteWeb.Retrospective.HistoryLive do
  @moduledoc """
  LiveView for the streamer dashboard showing albums listened in time periods as a cover wall.
  """

  use PremiereEcouteWeb, :live_view

  alias Phoenix.LiveView.AsyncResult
  alias PremiereEcoute.Sessions

  import PremiereEcouteWeb.Retrospective.PeriodHelpers

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
      |> assign(:selected_source, :album)
      |> assign(:show_modal, false)
      |> assign(:modal_session_id, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    period =
      case params["period"] do
        "month" -> :month
        "year" -> :year
        _ -> socket.assigns.selected_period
      end

    source =
      case params["source"] do
        "track" -> :track
        "album" -> :album
        _ -> socket.assigns.selected_source
      end

    year = parse_year(params["year"]) || socket.assigns.selected_year
    month = parse_month(params["month"]) || socket.assigns.selected_month

    socket = assign(socket, :selected_period, period)
    socket = assign(socket, :selected_year, year)
    socket = assign(socket, :selected_month, month)
    socket = assign(socket, :selected_source, source)

    user = socket.assigns.current_user

    socket
    |> assign(:albums_data, AsyncResult.loading())
    |> assign_async(:albums_data, fn ->
      items =
        case source do
          :album -> Sessions.get_albums_by_period(user, period, %{year: year, month: month})
          :track -> Sessions.get_singles_by_period(user, period, %{year: year, month: month})
        end

      {:ok, %{albums_data: %{source: source, items: items}}}
    end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("change_period", %{"period" => period_str, "year" => year_str, "month" => month_str}, socket) do
    period = String.to_existing_atom(period_str)
    {year, ""} = Integer.parse(year_str)
    {month, ""} = Integer.parse(month_str)

    url_params = build_params(period, year, month) |> Map.put("source", socket.assigns.selected_source)
    {:noreply, push_patch(socket, to: ~p"/retrospective/history?#{url_params}")}
  end

  @impl true
  def handle_event("change_source", %{"source" => source_str}, socket) do
    source = String.to_existing_atom(source_str)

    url_params =
      build_params(socket.assigns.selected_period, socket.assigns.selected_year, socket.assigns.selected_month)
      |> Map.put("source", source)

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

    params =
      build_params(socket.assigns.selected_period, new_date.year, new_date.month)
      |> Map.put("source", socket.assigns.selected_source)

    {:noreply, push_patch(socket, to: ~p"/retrospective/history?#{params}")}
  end

  @impl true
  def handle_event("toggle_period", _params, socket) do
    new_period = if socket.assigns.selected_period == :month, do: :year, else: :month

    params =
      build_params(new_period, socket.assigns.selected_year, socket.assigns.selected_month)
      |> Map.put("source", socket.assigns.selected_source)

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
end
