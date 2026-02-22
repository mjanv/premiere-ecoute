defmodule PremiereEcouteWeb.Retrospective.VotesLive do
  @moduledoc """
  LiveView for displaying viewer votes on albums by time periods as a cover wall.
  Shows albums with viewer notes using get_votes_by_period function.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography
  alias PremiereEcoute.Sessions

  import PremiereEcouteCore.Duration, only: [timer: 1]
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
          |> assign(:selected_period, :month)
          |> assign(:selected_year, current_date.year)
          |> assign(:selected_month, current_date.month)
          |> assign(:years_available, get_available_years())
          |> assign(:show_modal, false)
          |> assign(:modal_album_id, nil)

        {:ok, socket}
    end
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

    user = socket.assigns.current_user

    socket
    |> assign_async(:votes_data, fn ->
      votes = Sessions.get_votes_by_period(user, period, %{year: year, month: month})
      {:ok, %{votes_data: votes}}
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
    {:noreply, push_patch(socket, to: ~p"/retrospective/votes?#{url_params}")}
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

    params = build_params(socket.assigns.selected_period, new_date.year, new_date.month)
    {:noreply, push_patch(socket, to: ~p"/retrospective/votes?#{params}")}
  end

  @impl true
  def handle_event("toggle_period", _params, socket) do
    new_period = if socket.assigns.selected_period == :month, do: :year, else: :month

    params = build_params(new_period, socket.assigns.selected_year, socket.assigns.selected_month)
    {:noreply, push_patch(socket, to: ~p"/retrospective/votes?#{params}")}
  end

  @impl true
  def handle_event("show_album_details", %{"album_id" => album_id}, socket) do
    user_id = socket.assigns.current_user.twitch.user_id

    socket
    |> assign(:show_modal, true)
    |> assign(:modal_album_id, album_id)
    |> assign_async(:modal_data, fn -> load_modal_data(album_id, user_id) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    socket
    |> assign(:show_modal, false)
    |> assign(:modal_album_id, nil)
    |> assign(:modal_data, %{loading: false, ok?: false, result: nil})
    |> then(fn socket -> {:noreply, socket} end)
  end

  # Private helper functions
  defp load_modal_data(album_id, user_id) do
    case Discography.get_album(album_id) do
      nil ->
        {:ok, %{modal_data: nil}}

      album ->
        track_ids = Enum.map(album.tracks, & &1.id)
        votes = Sessions.get_track_votes_for_user(track_ids, user_id)
        votes_by_track = Enum.group_by(votes, & &1.track_id)

        {:ok, %{modal_data: %{album: album, votes_by_track: votes_by_track}}}
    end
  end

  defp get_track_votes(_user_id, track_id, votes_by_track) when is_map(votes_by_track) do
    Map.get(votes_by_track, track_id, [])
  end

  defp get_track_votes(_user_id, _track_id, _votes_data), do: []
end
