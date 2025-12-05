defmodule PremiereEcouteWeb.Twitch.History.AdsLive do
  @moduledoc """
  Displays detailed ad impression data from a Twitch history export.
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
    |> assign(:selected_period, "month")
    |> assign(:top_n_channels, 20)
    |> assign_async([:ads, :minutes], fn ->
      if File.exists?(file_path) do
        ads_df = History.Ads.VideoAdImpression.read(file_path)
        minutes_df = History.SiteHistory.MinuteWatched.read(file_path)
        total = DataFrame.n_rows(ads_df)

        by_roll_type =
          ads_df
          |> History.Ads.VideoAdImpression.group_by_roll_type()
          |> DataFrame.to_rows()

        by_channel =
          ads_df
          |> History.Ads.VideoAdImpression.group_by_channel()
          |> DataFrame.to_rows()

        {:ok, %{ads: %{total: total, by_roll_type: by_roll_type, by_channel: by_channel, df: ads_df}, minutes: minutes_df}}
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
  def handle_event("select_period", %{"period" => period}, socket) do
    {:noreply, assign(socket, :selected_period, period)}
  end

  @impl true
  def handle_event("update_top_n", %{"value" => value}, socket) do
    top_n = String.to_integer(value)
    {:noreply, assign(socket, :top_n_channels, top_n)}
  end

  defp timeline_stacked_data(ads_df, period) do
    {groups, label} = period_params(period)

    # Get all unique roll types
    roll_types =
      ads_df
      |> DataFrame.pull("roll_type")
      |> Series.distinct()
      |> Series.to_list()

    # Group and aggregate data
    grouped_data =
      ads_df
      |> DataFrame.group_by([:roll_type | groups])
      |> DataFrame.summarise(count: Series.count(roll_type))
      |> apply_period_sort(period)
      |> DataFrame.to_rows()
      |> Enum.map(fn row ->
        date = label.(row)
        %{"date" => date, "roll_type" => row["roll_type"] || "unknown", "count" => row["count"]}
      end)

    # For stacked data, we need to fill missing periods for each roll_type separately
    # then recombine them
    roll_types
    |> Enum.flat_map(fn roll_type ->
      grouped_data
      |> Enum.filter(&(&1["roll_type"] == roll_type))
      |> TimelineHelper.fill_missing_periods("count", period)
      |> Enum.map(&Map.put(&1, "roll_type", roll_type))
    end)
    |> Enum.sort_by(&{&1["date"], &1["roll_type"]})
  end

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

  defp apply_period_sort(df, "day"), do: DataFrame.sort_by(df, asc: year, asc: month, asc: day)
  defp apply_period_sort(df, "week"), do: DataFrame.sort_by(df, asc: year, asc: week)
  defp apply_period_sort(df, "month"), do: DataFrame.sort_by(df, asc: year, asc: month)
  defp apply_period_sort(df, "year"), do: DataFrame.sort_by(df, asc: year)

  defp top_channels(by_channel, n) do
    Enum.take(by_channel, n)
  end

  defp ads_per_hour_data(ads_df, minutes_df, period) do
    {groups, label} = period_params(period)

    # Group ads by period
    ads_by_period =
      ads_df
      |> DataFrame.group_by(groups)
      |> DataFrame.summarise(ad_count: Series.count(roll_type))
      |> DataFrame.to_rows()
      |> Map.new(fn row -> {label.(row), row["ad_count"]} end)

    # Group minutes watched by period
    minutes_by_period =
      minutes_df
      |> DataFrame.group_by(groups)
      |> DataFrame.summarise(total_minutes: Series.sum(minutes_watched_unadjusted))
      |> DataFrame.to_rows()
      |> Map.new(fn row -> {label.(row), row["total_minutes"]} end)

    # Combine and calculate ads per hour
    all_periods = MapSet.union(MapSet.new(Map.keys(ads_by_period)), MapSet.new(Map.keys(minutes_by_period)))

    all_periods
    |> Enum.map(fn date ->
      ad_count = Map.get(ads_by_period, date, 0)
      total_minutes = Map.get(minutes_by_period, date, 0)
      hours = total_minutes / 60.0
      ads_per_hour = if hours > 0, do: ad_count / hours, else: 0.0

      %{"date" => date, "ads_per_hour" => Float.round(ads_per_hour, 2)}
    end)
    |> Enum.sort_by(& &1["date"])
    |> TimelineHelper.fill_missing_periods("ads_per_hour", period)
  end
end
