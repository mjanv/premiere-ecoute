defmodule PremiereEcouteCore.Dataflow.Filters do
  @moduledoc false

  require Explorer.DataFrame, as: DF

  alias Explorer.Series

  @doc "Filters a DataFrame by column value."
  @spec filter(Explorer.DataFrame.t(), atom(), any()) :: Explorer.DataFrame.t()
  def filter(df, column, value), do: DF.filter(df, col(^column) == ^value)

  @doc "Filters a DataFrame to rows where column value is within the given range."
  @spec window(Explorer.DataFrame.t(), any(), any(), atom()) :: Explorer.DataFrame.t()
  def window(df, start, stop, column),
    do: DF.filter(df, ^start <= col(^column) and col(^column) <= ^stop)

  @doc "Filters a DataFrame by multiple exact column matches."
  @spec equals(Explorer.DataFrame.t(), list({atom(), any()})) :: Explorer.DataFrame.t()
  def equals(df, []), do: df
  def equals(df, [{n, q} | t]), do: df |> filter(n, q) |> equals(t)

  @doc "Filters a DataFrame by multiple column contains matches."
  @spec contains(Explorer.DataFrame.t(), list({atom(), any()})) :: Explorer.DataFrame.t()
  def contains(df, []), do: df

  def contains(df, [{n, q} | t]) do
    df
    |> DF.filter_with(&Series.contains(&1[n], q))
    |> contains(t)
  end

  @doc "Groups, summarizes, and sorts a DataFrame."
  @spec group(Explorer.DataFrame.t(), list(atom()), (any() -> any()), (any() -> any())) :: Explorer.DataFrame.t()
  def group(df, columns, summary, sorts) do
    df
    |> DF.group_by(columns)
    |> DF.summarise_with(summary)
    |> DF.sort_with(sorts)
  end
end
