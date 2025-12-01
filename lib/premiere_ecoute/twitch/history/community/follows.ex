defmodule PremiereEcoute.Twitch.History.Community.Follows do
  @moduledoc false

  require Explorer.DataFrame, as: DataFrame

  alias Explorer.Series

  alias PremiereEcouteCore.Dataflow.Filters
  alias PremiereEcouteCore.Dataflow.Sink
  alias PremiereEcouteCore.Dataflow.Statistics
  alias PremiereEcouteCore.Zipfile

  def read(file) do
    file
    |> Zipfile.csv(
      "request/community/follows/follow.csv",
      columns: ["time", "channel"],
      dtypes: [{"time", {:naive_datetime, :microsecond}}]
    )
    |> Sink.preprocess()
    |> DataFrame.filter(not is_nil(channel))
  end

  def all(df) do
    df
    |> DataFrame.sort_by(asc: time)
    |> DataFrame.group_by([:channel])
    |> DataFrame.summarise_with(&[follow: Explorer.Series.first(&1["time"])])
  end

  def n(file) do
    file
    |> read()
    |> Statistics.n_rows()
  end

  def group_month_year(df) do
    df
    |> Filters.group(
      [:month, :year],
      &[
        follows: Series.n_distinct(&1["channel"])
      ],
      &[desc: &1["follows"]]
    )
  end
end
