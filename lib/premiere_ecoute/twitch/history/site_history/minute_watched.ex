defmodule PremiereEcoute.Twitch.History.SiteHistory.MinuteWatched do
  @moduledoc false

  require Explorer.DataFrame, as: DataFrame

  alias Explorer.Series
  alias PremiereEcouteCore.Dataflow.Filters
  alias PremiereEcouteCore.Zipfile

  @dialyzer {:nowarn_function, remove_unwatched_channels: 2}

  def read(file) do
    file
    |> Zipfile.csv(
      "request/site_history/minute_watched.csv",
      columns: ["day", "channel_name", "minutes_watched_unadjusted", "platform", "player", "game_name"],
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

  def remove_unwatched_channels(df, threshold) do
    df
    |> DataFrame.group_by([:channel])
    |> DataFrame.filter(count(minutes_logged) > ^threshold)
    |> DataFrame.ungroup()
  end

  def group_day(df) do
    df
    |> DataFrame.group_by([:day])
    |> DataFrame.summarise_with(&[minutes: Series.sum(&1["minutes_watched_unadjusted"])])
  end

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
end
