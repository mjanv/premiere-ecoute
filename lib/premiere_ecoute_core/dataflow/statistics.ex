defmodule PremiereEcouteCore.Dataflow.Statistics do
  @moduledoc false

  alias Explorer.DataFrame

  @doc """
  Returns the number of rows in a dataframe

  A divider can be used to divide the number of rows by a factor
  """
  @spec n_rows(DataFrame.t(), integer()) :: integer()
  def n_rows(df, divider \\ 1) do
    df
    |> Explorer.DataFrame.n_rows()
    |> Kernel./(divider)
    |> Kernel.round()
  end
end
