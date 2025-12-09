defmodule PremiereEcoute.Twitch.History.SiteHistory.MinuteWatched do
  @moduledoc false

  require Explorer.DataFrame, as: DataFrame

  alias Explorer.Series
  alias PremiereEcouteCore.Dataflow.Filters
  alias PremiereEcouteCore.Zipfile

  @dialyzer {:nowarn_function, remove_unwatched_channels: 2}

  @doc "Reads minute watched data from a zip file."
  @spec read(String.t()) :: Explorer.DataFrame.t()
  def read(file) do
    file
    |> Zipfile.csv(
      "request/site_history/minute_watched.csv",
      columns: ["day", "channel_name", "minutes_watched_unadjusted", "platform", "player", "game_name", "content_mode"],
      dtypes: [{"day", :date}]
    )
    |> DataFrame.mutate_with(
      &[
        year: Series.year(&1["day"]),
        month: Series.month(&1["day"]),
        week: Series.week_of_year(&1["day"]),
        day: Series.day_of_year(&1["day"])
      ]
    )
  end

  @doc "Removes channels with watch count below threshold."
  @spec remove_unwatched_channels(Explorer.DataFrame.t(), non_neg_integer()) :: Explorer.DataFrame.t()
  def remove_unwatched_channels(df, threshold) do
    df
    |> DataFrame.group_by([:channel])
    |> DataFrame.filter(count(minutes_logged) > ^threshold)
    |> DataFrame.ungroup()
  end

  @doc "Groups watch data by day."
  @spec group_day(Explorer.DataFrame.t()) :: Explorer.DataFrame.t()
  def group_day(df) do
    df
    |> DataFrame.group_by([:day])
    |> DataFrame.summarise_with(&[minutes: Series.sum(&1["minutes_watched_unadjusted"])])
  end

  @doc "Groups watch data by channel name."
  @spec group_channel(Explorer.DataFrame.t()) :: Explorer.DataFrame.t()
  def group_channel(df) do
    df
    |> Filters.group(
      [:channel_name],
      &[
        minutes: Series.sum(&1["minutes_watched_unadjusted"]) |> Series.cast(:integer)
      ],
      &[desc: &1["minutes"]]
    )
  end

  @doc "Groups watch data by channel, month, and year."
  @spec group_month_year(Explorer.DataFrame.t()) :: Explorer.DataFrame.t()
  def group_month_year(df) do
    df
    |> Filters.group(
      [:channel, :month, :year],
      &[
        hours: Series.count(&1["minutes_logged"]) |> Series.divide(60) |> Series.cast(:integer),
        channels: Series.n_distinct(&1["channel"])
      ],
      &[desc: &1["hours"]]
    )
  end

  @doc "Groups watch data by platform and time period."
  @spec group_by_platform_and_period(Explorer.DataFrame.t(), String.t()) :: Explorer.DataFrame.t()
  def group_by_platform_and_period(df, period) do
    groups = period_groups(period)

    df
    |> DataFrame.group_by([:platform | groups])
    |> DataFrame.summarise(minutes: Series.sum(minutes_watched_unadjusted))
    |> apply_period_sort(period)
  end

  @doc "Groups watch data by content mode and time period."
  @spec group_by_content_mode_and_period(Explorer.DataFrame.t(), String.t()) :: Explorer.DataFrame.t()
  def group_by_content_mode_and_period(df, period) do
    groups = period_groups(period)

    df
    |> DataFrame.group_by([:content_mode | groups])
    |> DataFrame.summarise(minutes: Series.sum(minutes_watched_unadjusted))
    |> apply_period_sort(period)
  end

  defp period_groups("week"), do: [:year, :week]
  defp period_groups("month"), do: [:year, :month]
  defp period_groups("year"), do: [:year]

  defp apply_period_sort(df, "week"), do: DataFrame.sort_by(df, asc: year, asc: week)
  defp apply_period_sort(df, "month"), do: DataFrame.sort_by(df, asc: year, asc: month)
  defp apply_period_sort(df, "year"), do: DataFrame.sort_by(df, asc: year)
end
