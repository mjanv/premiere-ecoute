defmodule PremiereEcoute.Twitch.History.SiteHistory.ChatMessages do
  @moduledoc false

  alias Explorer.Series
  alias PremiereEcouteCore.Dataflow.Filters
  alias PremiereEcouteCore.Dataflow.Sink
  alias PremiereEcouteCore.Zipfile

  def read(file) do
    file
    |> Zipfile.csv(
      "request/site_history/chat_messages.csv",
      columns: [
        "time",
        "channel",
        "body",
        "body_full",
        "is_reply",
        "is_mention",
        "channel_points_modification"
      ],
      dtypes: [{"time", {:naive_datetime, :microsecond}}]
    )
    |> Sink.preprocess()
  end

  def group_channel(df) do
    df
    |> Filters.group(
      [:channel],
      &[messages: Series.count(&1["body"]) |> Series.cast(:integer)],
      &[desc: &1["messages"]]
    )
  end

  def group_month_year(df) do
    df
    |> Filters.group(
      [:channel, :month, :year],
      &[messages: Series.count(&1["body"]) |> Series.cast(:integer)],
      &[desc: &1["messages"]]
    )
  end

  def activity_heatmap(df) do
    require Explorer.DataFrame, as: DataFrame

    df
    |> DataFrame.group_by([:weekday, :hour])
    |> DataFrame.summarise(messages: Series.count(body))
    |> DataFrame.to_rows()
  end
end
