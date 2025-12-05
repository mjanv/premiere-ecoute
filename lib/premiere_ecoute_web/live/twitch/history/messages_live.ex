defmodule PremiereEcouteWeb.Twitch.History.MessagesLive do
  @moduledoc """
  Displays detailed chat messages data from a Twitch history export.
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
    |> assign(:dropdown_open, false)
    |> assign(:top_n_channels, 20)
    |> assign_async(:messages, fn ->
      if File.exists?(file_path) do
        messages_df = History.SiteHistory.ChatMessages.read(file_path)
        total = DataFrame.n_rows(messages_df)

        messages_by_channel =
          messages_df
          |> History.SiteHistory.ChatMessages.group_channel()
          |> DataFrame.filter_with(fn df -> Series.greater(df["messages"], 10) end)
          |> DataFrame.sort_by(desc: messages)
          |> DataFrame.to_rows()

        heatmap_data = History.SiteHistory.ChatMessages.activity_heatmap(messages_df)

        {:ok, %{messages: %{total: total, by_channel: messages_by_channel, heatmap: heatmap_data, df: messages_df}}}
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
  def handle_event("update_top_n", %{"value" => value}, socket) do
    top_n = String.to_integer(value)
    {:noreply, assign(socket, :top_n_channels, top_n)}
  end

  defp graph_data(by_channel) do
    Enum.map(by_channel, fn row ->
      %{"channel" => row["channel"], "messages" => row["messages"]}
    end)
  end

  defp top_n_channels(by_channel, n) do
    Enum.take(by_channel, n)
  end

  defp channel_timeline_data([], _period, _df), do: []

  defp channel_timeline_data(channels, period, messages_df) when is_list(channels) do
    {groups, label} = period_params(period)

    # Process each channel separately to fill missing periods
    data =
      channels
      |> Enum.flat_map(fn channel ->
        messages_df
        |> DataFrame.filter_with(fn df -> Series.equal(df["channel"], channel) end)
        |> DataFrame.group_by(groups)
        |> DataFrame.summarise(messages: Series.count(body))
        |> apply_period_sort(period)
        |> DataFrame.to_rows()
        |> Enum.map(fn row ->
          date = label.(row)
          %{"date" => date, "channel" => channel, "messages" => row["messages"]}
        end)
        |> TimelineHelper.fill_missing_periods("messages", period)
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

  defp format_heatmap_data(heatmap_data) do
    # Create a map for quick lookup
    data_map =
      heatmap_data
      |> Enum.map(fn row -> {{row["weekday"], row["hour"]}, row["messages"]} end)
      |> Map.new()

    # Find max for color intensity
    max_messages = heatmap_data |> Enum.map(& &1["messages"]) |> Enum.max(fn -> 1 end)

    # Generate all cells (7 days × 24 hours)
    # Note: Explorer's day_of_week returns 1-7 (Monday=1, Sunday=7)
    for weekday <- 1..7, hour <- 0..23 do
      messages = Map.get(data_map, {weekday, hour}, 0)
      intensity = if max_messages > 0, do: messages / max_messages, else: 0

      %{
        "weekday" => weekday,
        "weekday_name" => weekday_name(weekday),
        "hour" => hour,
        "messages" => messages,
        "intensity" => intensity
      }
    end
  end

  defp weekday_name(day) do
    case day do
      1 -> "Mon"
      2 -> "Tue"
      3 -> "Wed"
      4 -> "Thu"
      5 -> "Fri"
      6 -> "Sat"
      7 -> "Sun"
    end
  end
end
