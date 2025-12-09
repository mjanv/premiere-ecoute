defmodule PremiereEcouteCore.Dataflow.Sink do
  @moduledoc false

  require Explorer.DataFrame, as: DF

  alias Explorer.Series

  @callback read(String.t()) :: nil | Explorer.DataFrame.t()

  defmacro __using__(opts) do
    file = Keyword.get(opts, :file)
    columns = Keyword.get(opts, :columns)

    quote do
      @behaviour unquote(__MODULE__)

      alias PremiereEcoute.Zipfile

      @impl true
      @doc "Default read operation"
      @spec read(String.t()) :: Explorer.DataFrame.t()
      def read(file) do
        Zipfile.csv(
          unquote(file),
          unquote(columns),
          dtypes: [{"time", {:naive_datetime, :microsecond}}]
        )
      end
    end
  end

  @doc "Preprocesses a DataFrame by adding time-based columns (year, month, week, day, weekday, hour)."
  @spec preprocess(Explorer.DataFrame.t()) :: Explorer.DataFrame.t()
  @spec preprocess(Explorer.DataFrame.t(), String.t()) :: Explorer.DataFrame.t()
  def preprocess(df, column \\ "time") do
    df
    |> DF.mutate_with(
      &[
        year: Series.year(&1[column]),
        month: Series.month(&1[column]),
        week: Series.week_of_year(&1[column]),
        day: Series.day_of_year(&1[column]),
        weekday: Series.day_of_week(&1[column]),
        hour: Series.hour(&1[column])
      ]
    )
  end

  @doc "Converts a time column to a nominal date column in YYYY-MM format."
  @spec nominal_date_column(Explorer.DataFrame.t()) :: Explorer.DataFrame.t()
  @spec nominal_date_column(Explorer.DataFrame.t(), String.t()) :: Explorer.DataFrame.t()
  def nominal_date_column(df, column \\ "time") do
    {df["year"], df["month"]}
    |> then(fn {y, m} -> Enum.zip(as_string(y), as_string(m)) end)
    |> Enum.map(fn {y, m} -> "#{y}-#{String.pad_leading(m, 2, "0")}" end)
    |> Series.from_list()
    |> then(fn s -> DF.put(df, column, s) end)
  end

  defp as_string(s), do: s |> Series.cast(:string) |> Series.to_list()
end
