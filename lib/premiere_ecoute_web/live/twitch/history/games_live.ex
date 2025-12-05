defmodule PremiereEcouteWeb.Twitch.History.GamesLive do
  @moduledoc """
  Displays detailed game analytics from Twitch history export.
  """

  use PremiereEcouteWeb, :live_view

  require Explorer.DataFrame, as: DataFrame

  alias Explorer.Series
  alias PremiereEcoute.Twitch.History
  alias PremiereEcoute.Twitch.History.TimelineHelper

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    file_path = Path.join("priv/static/uploads", id)

    socket
    |> assign(:filename, id)
    |> assign(:file_path, file_path)
    |> assign(:selected_games, [])
    |> assign(:selected_period, "month")
    |> assign(:dropdown_open, false)
    |> assign(:top_n_games, 20)
    |> assign_async(:games, fn ->
      if File.exists?(file_path) do
        minutes_df = History.SiteHistory.MinuteWatched.read(file_path)

        games_by_minutes =
          minutes_df
          |> DataFrame.filter_with(fn df ->
            df["game_name"]
            |> Series.is_not_nil()
            |> Series.and(Series.not_equal(df["game_name"], ""))
          end)
          |> DataFrame.group_by([:game_name])
          |> DataFrame.summarise(minutes: Series.sum(minutes_watched_unadjusted))
          |> DataFrame.filter_with(fn df -> Series.greater(df["minutes"], 0) end)
          |> DataFrame.sort_by(desc: minutes)
          |> DataFrame.to_rows()

        total_minutes = Enum.sum(Enum.map(games_by_minutes, & &1["minutes"]))

        {:ok, %{games: %{total_minutes: total_minutes, by_game: games_by_minutes, df: minutes_df}}}
      else
        {:error, "No file"}
      end
    end)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_dropdown", _params, socket) do
    {:noreply, assign(socket, :dropdown_open, !socket.assigns.dropdown_open)}
  end

  @impl true
  def handle_event("toggle_game", %{"game" => game}, socket) do
    selected_games = socket.assigns.selected_games

    new_games =
      if game in selected_games do
        List.delete(selected_games, game)
      else
        [game | selected_games]
      end

    {:noreply, assign(socket, :selected_games, new_games)}
  end

  @impl true
  def handle_event("select_period", %{"period" => period}, socket) do
    {:noreply, assign(socket, :selected_period, period)}
  end

  @impl true
  def handle_event("update_top_n", %{"value" => value}, socket) do
    top_n = String.to_integer(value)
    {:noreply, assign(socket, :top_n_games, top_n)}
  end

  defp top_n_games(by_game, n) do
    Enum.take(by_game, n)
  end

  defp game_timeline_data([], _period, _df), do: []

  defp game_timeline_data(games, period, minutes_df) when is_list(games) do
    {groups, label} = period_params(period)

    # Process each game separately to fill missing periods
    data =
      games
      |> Enum.flat_map(fn game ->
        minutes_df
        |> DataFrame.filter_with(fn df -> Series.equal(df["game_name"], game) end)
        |> DataFrame.group_by(groups)
        |> DataFrame.summarise(minutes: Series.sum(minutes_watched_unadjusted))
        |> apply_period_sort(period)
        |> DataFrame.to_rows()
        |> Enum.map(fn row ->
          date = label.(row)
          %{"date" => date, "game" => game, "minutes" => row["minutes"]}
        end)
        |> TimelineHelper.fill_missing_periods("minutes", period)
        |> Enum.map(&Map.put(&1, "game", game))
      end)

    sort_by_selection_order(data, games, "game")
  end

  defp sort_by_selection_order(data, order_list, key) do
    order_map = order_list |> Enum.with_index() |> Map.new()

    Enum.sort_by(data, fn item ->
      Map.get(order_map, item[key], 9999)
    end)
  end

  defp apply_period_sort(df, "day"), do: DataFrame.sort_by(df, asc: year, asc: month, asc: day)
  defp apply_period_sort(df, "week"), do: DataFrame.sort_by(df, asc: year, asc: week)
  defp apply_period_sort(df, "month"), do: DataFrame.sort_by(df, asc: year, asc: month)
  defp apply_period_sort(df, "year"), do: DataFrame.sort_by(df, asc: year)

  defp period_params(period) do
    case period do
      "day" ->
        {[:year, :month, :day],
         fn %{"year" => y, "month" => m, "day" => d} ->
           "#{y}-#{String.pad_leading(to_string(m), 2, "0")}-#{String.pad_leading(to_string(d), 2, "0")}"
         end}

      "week" ->
        {[:year, :week], fn %{"year" => y, "week" => w} -> "#{y}-W#{String.pad_leading(to_string(w), 2, "0")}" end}

      "month" ->
        {[:year, :month], fn %{"year" => y, "month" => m} -> "#{y}-#{String.pad_leading(to_string(m), 2, "0")}" end}

      "year" ->
        {[:year], fn %{"year" => y} -> "#{y}" end}
    end
  end

  defp format_minutes(minutes) when is_number(minutes) do
    cond do
      minutes < 60 ->
        "#{round(minutes)}m"

      minutes < 1440 ->
        hours = div(round(minutes), 60)
        remaining_minutes = rem(round(minutes), 60)

        if remaining_minutes > 0 do
          "#{hours}h #{remaining_minutes}m"
        else
          "#{hours}h"
        end

      true ->
        days = div(round(minutes), 1440)
        remaining_hours = div(rem(round(minutes), 1440), 60)

        if remaining_hours > 0 do
          "#{days}d #{remaining_hours}h"
        else
          "#{days}d"
        end
    end
  end

  defp format_minutes(_), do: "0m"
end
