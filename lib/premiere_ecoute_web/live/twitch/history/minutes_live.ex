defmodule PremiereEcouteWeb.Twitch.History.MinutesLive do
  @moduledoc """
  Displays detailed minutes watched data from a Twitch history export.
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
    |> assign(:selected_channels, [])
    |> assign(:selected_period, "month")
    |> assign(:platform_period, "month")
    |> assign(:content_mode_period, "month")
    |> assign(:platform_display_mode, "absolute")
    |> assign(:content_mode_display_mode, "absolute")
    |> assign(:dropdown_open, false)
    |> assign(:top_n_channels, 20)
    |> assign_async(:minutes, fn ->
      if File.exists?(file_path) do
        minutes_df = History.SiteHistory.MinuteWatched.read(file_path)
        total = minutes_df["minutes_watched_unadjusted"] |> Series.sum() |> round()

        minutes_by_channel =
          minutes_df
          |> History.SiteHistory.MinuteWatched.group_channel()
          |> DataFrame.filter_with(fn df -> Series.greater(df["minutes"], 0) end)
          |> DataFrame.sort_by(desc: minutes)
          |> DataFrame.to_rows()

        {:ok, %{minutes: %{total: total, by_channel: minutes_by_channel, df: minutes_df}}}
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
  def handle_event("toggle_channel", %{"channel" => channel}, socket) do
    selected_channels = socket.assigns.selected_channels

    new_channels =
      if channel in selected_channels do
        List.delete(selected_channels, channel)
      else
        [channel | selected_channels]
      end

    {:noreply, assign(socket, :selected_channels, new_channels)}
  end

  @impl true
  def handle_event("select_period", %{"period" => period}, socket) do
    {:noreply, assign(socket, :selected_period, period)}
  end

  @impl true
  def handle_event("select_platform_period", %{"period" => period}, socket) do
    {:noreply, assign(socket, :platform_period, period)}
  end

  @impl true
  def handle_event("select_content_mode_period", %{"period" => period}, socket) do
    {:noreply, assign(socket, :content_mode_period, period)}
  end

  @impl true
  def handle_event("toggle_platform_display_mode", _params, socket) do
    new_mode = if socket.assigns.platform_display_mode == "absolute", do: "percentage", else: "absolute"
    {:noreply, assign(socket, :platform_display_mode, new_mode)}
  end

  @impl true
  def handle_event("toggle_content_mode_display_mode", _params, socket) do
    new_mode = if socket.assigns.content_mode_display_mode == "absolute", do: "percentage", else: "absolute"
    {:noreply, assign(socket, :content_mode_display_mode, new_mode)}
  end

  @impl true
  def handle_event("update_top_n", %{"value" => value}, socket) do
    top_n = String.to_integer(value)
    {:noreply, assign(socket, :top_n_channels, top_n)}
  end

  defp graph_data(by_channel) do
    Enum.map(by_channel, fn row ->
      %{"channel" => row["channel_name"], "minutes" => row["minutes"]}
    end)
  end

  defp top_n_channels(by_channel, n) do
    Enum.take(by_channel, n)
  end

  defp channel_timeline_data([], _period, _df), do: []

  defp channel_timeline_data(channels, period, minutes_df) when is_list(channels) do
    {groups, label} = period_params(period)

    # Process each channel separately to fill missing periods
    data =
      channels
      |> Enum.flat_map(fn channel ->
        minutes_df
        |> DataFrame.filter_with(fn df -> Series.equal(df["channel_name"], channel) end)
        |> DataFrame.group_by(groups)
        |> DataFrame.summarise(minutes: Series.sum(minutes_watched_unadjusted))
        |> apply_period_sort(period)
        |> DataFrame.to_rows()
        |> Enum.map(fn row ->
          date = label.(row)
          %{"date" => date, "channel" => channel, "minutes" => row["minutes"]}
        end)
        |> TimelineHelper.fill_missing_periods("minutes", period)
        |> Enum.map(&Map.put(&1, "channel", channel))
      end)

    # Sort data by selection order to preserve it in the legend
    sort_by_selection_order(data, channels, "channel")
  end

  defp sort_by_selection_order(data, order_list, key) do
    # Create a map of item -> index for the desired order
    order_map = order_list |> Enum.with_index() |> Map.new()

    # Sort data by the selection order
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

  defp platform_breakdown_data(minutes_df, period, display_mode) do
    # Get all unique platforms
    platforms =
      minutes_df
      |> DataFrame.pull("platform")
      |> Series.distinct()
      |> Series.to_list()

    # Group and fill missing periods for each platform
    raw_data =
      platforms
      |> Enum.flat_map(fn platform ->
        minutes_df
        |> DataFrame.filter_with(fn df -> Series.equal(df["platform"], platform) end)
        |> History.SiteHistory.MinuteWatched.group_by_platform_and_period(period)
        |> DataFrame.to_rows()
        |> Enum.map(fn row ->
          date = format_period_label(row, period)
          %{"date" => date, "platform" => row["platform"] || "unknown", "minutes" => row["minutes"]}
        end)
        |> TimelineHelper.fill_missing_periods("minutes", period)
        |> Enum.map(&Map.put(&1, "platform", platform || "unknown"))
      end)

    if display_mode == "percentage" do
      convert_to_percentage(raw_data, "platform")
    else
      raw_data
    end
  end

  defp content_mode_breakdown_data(minutes_df, period, display_mode) do
    # Get all unique content modes
    content_modes =
      minutes_df
      |> DataFrame.pull("content_mode")
      |> Series.distinct()
      |> Series.to_list()

    # Group and fill missing periods for each content mode
    raw_data =
      content_modes
      |> Enum.flat_map(fn content_mode ->
        minutes_df
        |> DataFrame.filter_with(fn df -> Series.equal(df["content_mode"], content_mode) end)
        |> History.SiteHistory.MinuteWatched.group_by_content_mode_and_period(period)
        |> DataFrame.to_rows()
        |> Enum.map(fn row ->
          date = format_period_label(row, period)
          %{"date" => date, "content_mode" => row["content_mode"] || "unknown", "minutes" => row["minutes"]}
        end)
        |> TimelineHelper.fill_missing_periods("minutes", period)
        |> Enum.map(&Map.put(&1, "content_mode", content_mode || "unknown"))
      end)

    if display_mode == "percentage" do
      convert_to_percentage(raw_data, "content_mode")
    else
      raw_data
    end
  end

  defp convert_to_percentage(data, _group_field) do
    # Group by date and calculate totals
    date_totals =
      data
      |> Enum.group_by(& &1["date"])
      |> Enum.map(fn {date, rows} ->
        total = Enum.sum(Enum.map(rows, & &1["minutes"]))
        {date, total}
      end)
      |> Map.new()

    # Convert each row to percentage
    Enum.map(data, fn row ->
      date = row["date"]
      total = Map.get(date_totals, date, 1)
      percentage = if total > 0, do: row["minutes"] / total * 100, else: 0
      %{row | "minutes" => Float.round(percentage, 2)}
    end)
  end

  defp format_period_label(row, "week") do
    "#{row["year"]}-W#{String.pad_leading(to_string(row["week"]), 2, "0")}"
  end

  defp format_period_label(row, "month") do
    "#{row["year"]}-#{String.pad_leading(to_string(row["month"]), 2, "0")}"
  end

  defp format_period_label(row, "year") do
    "#{row["year"]}"
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
