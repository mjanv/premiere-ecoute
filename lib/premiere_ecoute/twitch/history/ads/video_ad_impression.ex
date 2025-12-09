defmodule PremiereEcoute.Twitch.History.Ads.VideoAdImpression do
  @moduledoc false

  require Explorer.DataFrame, as: DataFrame

  alias Explorer.Series
  alias PremiereEcouteCore.Zipfile

  @doc "Reads video ad impression data from a zip file."
  @spec read(String.t()) :: Explorer.DataFrame.t()
  def read(file) do
    file
    |> Zipfile.csv(
      "request/ads/video_ad_impression.csv",
      columns: ["time", "roll_type", "channel"],
      dtypes: [{"time", {:naive_datetime, :microsecond}}]
    )
    |> DataFrame.mutate_with(
      &[
        year: Series.year(&1["time"]),
        month: Series.month(&1["time"]),
        week: Series.week_of_year(&1["time"]),
        day: Series.day_of_year(&1["time"]),
        weekday: Series.day_of_week(&1["time"]),
        hour: Series.hour(&1["time"])
      ]
    )
  end

  @doc "Groups video ad impressions by time period."
  @spec group_by_period(Explorer.DataFrame.t(), String.t()) :: Explorer.DataFrame.t()
  def group_by_period(df, period) do
    groups = period_groups(period)

    df
    |> DataFrame.group_by(groups)
    |> DataFrame.summarise(impressions: Series.count(roll_type))
    |> apply_period_sort(period)
  end

  @doc "Groups video ad impressions by roll type (pre-roll, mid-roll, etc.)."
  @spec group_by_roll_type(Explorer.DataFrame.t()) :: Explorer.DataFrame.t()
  def group_by_roll_type(df) do
    df
    |> DataFrame.group_by([:roll_type])
    |> DataFrame.summarise(impressions: Series.count(roll_type))
    |> DataFrame.sort_by(desc: impressions)
  end

  @doc "Groups video ad impressions by channel."
  @spec group_by_channel(Explorer.DataFrame.t()) :: Explorer.DataFrame.t()
  def group_by_channel(df) do
    df
    |> DataFrame.group_by([:channel])
    |> DataFrame.summarise(impressions: Series.count(roll_type))
    |> DataFrame.sort_by(desc: impressions)
  end

  defp period_groups("day"), do: [:year, :month, :day]
  defp period_groups("week"), do: [:year, :week]
  defp period_groups("month"), do: [:year, :month]
  defp period_groups("year"), do: [:year]

  defp apply_period_sort(df, "day"), do: DataFrame.sort_by(df, asc: year, asc: month, asc: day)
  defp apply_period_sort(df, "week"), do: DataFrame.sort_by(df, asc: year, asc: week)
  defp apply_period_sort(df, "month"), do: DataFrame.sort_by(df, asc: year, asc: month)
  defp apply_period_sort(df, "year"), do: DataFrame.sort_by(df, asc: year)
end
