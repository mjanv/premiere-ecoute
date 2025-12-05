defmodule PremiereEcouteCore.Dataflow.Filters do
  @moduledoc false

  require Explorer.DataFrame, as: DF

  alias Explorer.Series

  def filter(df, column, value), do: DF.filter(df, col(^column) == ^value)

  def window(df, start, stop, column),
    do: DF.filter(df, ^start <= col(^column) and col(^column) <= ^stop)

  def equals(df, []), do: df
  def equals(df, [{n, q} | t]), do: df |> filter(n, q) |> equals(t)

  def contains(df, []), do: df

  def contains(df, [{n, q} | t]) do
    df
    |> DF.filter_with(&Series.contains(&1[n], q))
    |> contains(t)
  end

  def group(df, columns, summary, sorts) do
    df
    |> DF.group_by(columns)
    |> DF.summarise_with(summary)
    |> DF.sort_with(sorts)
  end
end
