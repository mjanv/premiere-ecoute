defmodule PremiereEcouteWeb.Sessions.Retrospective.VotesLive do
  @moduledoc """
  LiveView for displaying viewer votes on albums by time periods as a cover wall.
  Shows albums with viewer notes using get_votes_by_period function.
  """

  use PremiereEcouteWeb, :live_view

  alias Phoenix.LiveView.AsyncResult
  alias PremiereEcoute.Sessions

  import PremiereEcouteWeb.Retrospective.PeriodHelpers

  @impl true
  def mount(_params, _session, socket) do
    current_date = DateTime.utc_now()

    socket
    |> assign(:current_user, socket.assigns.current_scope.user)
    |> assign(:selected_period, :month)
    |> assign(:selected_year, current_date.year)
    |> assign(:selected_month, current_date.month)
    |> assign(:years_available, get_available_years())
    |> assign(:selected_source, :album)
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

    source =
      case params["source"] do
        "track" -> :track
        "album" -> :album
        "playlist" -> :playlist
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
    |> assign(:votes_data, AsyncResult.loading())
    |> assign_async(:votes_data, fn ->
      votes =
        case source do
          :album -> Sessions.get_votes_by_period(user, period, %{year: year, month: month})
          :track -> Sessions.get_single_votes_by_period(user, period, %{year: year, month: month})
          :playlist -> Sessions.get_playlist_votes_by_period(user, period, %{year: year, month: month})
        end

      {:ok, %{votes_data: %{source: source, items: votes}}}
    end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("change_source", %{"source" => source_str}, socket) do
    source = String.to_existing_atom(source_str)

    url_params =
      build_params(socket.assigns.selected_period, socket.assigns.selected_year, socket.assigns.selected_month)
      |> Map.put("source", source)

    {:noreply, push_patch(socket, to: ~p"/sessions/retrospective/votes?#{url_params}")}
  end

  @impl true
  def handle_event("change_period", %{"period" => period_str, "year" => year_str, "month" => month_str}, socket) do
    period = String.to_existing_atom(period_str)
    {year, ""} = Integer.parse(year_str)
    {month, ""} = Integer.parse(month_str)

    url_params = build_params(period, year, month) |> Map.put("source", socket.assigns.selected_source)
    {:noreply, push_patch(socket, to: ~p"/sessions/retrospective/votes?#{url_params}")}
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
      end

    params =
      build_params(socket.assigns.selected_period, new_date.year, new_date.month)
      |> Map.put("source", socket.assigns.selected_source)

    {:noreply, push_patch(socket, to: ~p"/sessions/retrospective/votes?#{params}")}
  end

  @impl true
  def handle_event("toggle_period", _params, socket) do
    new_period = if socket.assigns.selected_period == :month, do: :year, else: :month

    params =
      build_params(new_period, socket.assigns.selected_year, socket.assigns.selected_month)
      |> Map.put("source", socket.assigns.selected_source)

    {:noreply, push_patch(socket, to: ~p"/sessions/retrospective/votes?#{params}")}
  end
end
