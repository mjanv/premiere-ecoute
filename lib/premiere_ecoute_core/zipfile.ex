defmodule PremiereEcouteCore.Zipfile do
  @moduledoc false

  require Explorer.DataFrame, as: DataFrame
  require Logger

  @doc "Returns the list of files in a zip file"
  @spec list(String.t()) :: [String.t()]
  def list(file) do
    file
    |> to_charlist()
    |> :zip.list_dir()
    |> then(fn {:ok, list} -> list end)
    |> Enum.map(fn
      {:zip_comment, _} -> nil
      {:zip_file, path, _, _, _, _} -> path
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&to_string/1)
  end

  @doc "Returns the content of a JSON file in a zip file"
  @spec json(String.t(), String.t()) :: term() | nil
  def json(file, path) do
    with {:ok, [{_, binary}]} <- :zip.extract(to_charlist(file), [:memory, {:file_list, [to_charlist(path)]}]),
         {:ok, map} <- Jason.decode(binary) do
      map
    else
      {:ok, _} ->
        Logger.error("No JSON file found in zip file #{file} at #{path}")
        nil

      {:error, reason} ->
        Logger.error("Failed to read JSON file #{path} in zip file #{file}: #{inspect(reason)}")
        nil
    end
  end

  @doc "Returns the content of a CSV file in a zip file"
  @spec csv(String.t(), String.t(), Keyword.t()) :: Explorer.DataFrame.t() | nil
  def csv(file, path, opts \\ []) do
    with {:ok, [{_, binary}]} <-
           :zip.extract(to_charlist(file), [:memory, {:file_list, [to_charlist(path)]}]),
         tmp_path = Path.join(System.tmp_dir!(), "df.csv"),
         :ok <- File.write(tmp_path, binary),
         {:ok, df} <- DataFrame.from_csv(tmp_path, opts) do
      df
    else
      {:ok, _} ->
        Logger.error("No CSV file found in zip file #{file} at #{path}")
        nil

      {:error, reason} ->
        Logger.error("Failed to read CSV file #{path} in zip file #{file}: #{inspect(reason)}")
        nil
    end
  end
end
