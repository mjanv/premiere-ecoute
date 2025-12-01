defmodule PremiereEcoute.ExplorerCase do
  @moduledoc false

  alias Explorer.{DataFrame, Series}

  def equal_master?(df, name) do
    case System.get_env("GOLDEN_MASTER", "false") do
      "false" ->
        dataframes_equal?(df, read_dataframe(name))
        df

      _ ->
        df
        |> store_dataframe(name)
        |> case do
          :ok -> true
          {:error, _} -> false
        end
    end
  end

  defp store_dataframe(df, name), do: DataFrame.to_parquet(df, path(name))
  defp read_dataframe(name), do: DataFrame.from_parquet!(path(name))
  defp path(name), do: "test/support/data/#{name}.parquet"

  defp dataframes_equal?(df1, df2) do
    dtype = DataFrame.dtypes(df1) == DataFrame.dtypes(df2)
    names = DataFrame.names(df1) == DataFrame.names(df2)
    shape = DataFrame.shape(df1) == DataFrame.shape(df2)

    columns =
      Enum.all?(
        for column <- DataFrame.names(df1) do
          Series.all_equal(df1[column], df2[column])
        end
      )

    Enum.all?([dtype, names, shape, columns])
  end
end
