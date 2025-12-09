defmodule PremiereEcoute.Twitch.History.SiteHistory.ChatMessages do
  @moduledoc false

  alias Explorer.Series
  alias PremiereEcouteCore.Dataflow.Filters
  alias PremiereEcouteCore.Dataflow.Sink
  alias PremiereEcouteCore.Zipfile

  @doc "Reads chat message data from a zip file."
  @spec read(String.t()) :: Explorer.DataFrame.t()
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

  @doc "Groups chat messages by channel."
  @spec group_channel(Explorer.DataFrame.t()) :: Explorer.DataFrame.t()
  def group_channel(df) do
    df
    |> Filters.group(
      [:channel],
      &[messages: Series.count(&1["body"]) |> Series.cast(:integer)],
      &[desc: &1["messages"]]
    )
  end

  @doc "Groups chat messages by channel, month, and year."
  @spec group_month_year(Explorer.DataFrame.t()) :: Explorer.DataFrame.t()
  def group_month_year(df) do
    df
    |> Filters.group(
      [:channel, :month, :year],
      &[messages: Series.count(&1["body"]) |> Series.cast(:integer)],
      &[desc: &1["messages"]]
    )
  end

  @doc "Generates activity heatmap data by weekday and hour."
  @spec activity_heatmap(Explorer.DataFrame.t()) :: list(map())
  def activity_heatmap(df) do
    require Explorer.DataFrame, as: DataFrame

    df
    |> DataFrame.group_by([:weekday, :hour])
    |> DataFrame.summarise(messages: Series.count(body))
    |> DataFrame.to_rows()
  end
end
