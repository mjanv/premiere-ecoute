defmodule PremiereEcouteCore.Search do
  @moduledoc """
  Search and filtering utilities.

  Provides functions for fuzzy text search using Jaro distance, field-based filtering, and date-aware sorting of data collections.
  """

  @doc """
  Filters data using fuzzy text search across specified fields.

  Searches fields using Jaro distance algorithm with configurable similarity threshold. Returns results sorted by relevance score descending. Empty queries return all data.
  """
  @spec filter(list(struct()), String.t(), list(atom()), float()) :: list(struct())
  def filter(data, query, fields, threshold \\ 0.8)

  def filter(data, "", _, _), do: data

  def filter(data, query, fields, threshold) do
    query = String.downcase(query)

    data
    |> Enum.map(fn struct ->
      fields
      |> Enum.map(fn field ->
        value = String.downcase(to_string(Map.get(struct, field, "")))
        String.jaro_distance(query, value)
      end)
      |> Enum.max()
      |> then(fn score -> {score, struct} end)
    end)
    |> Enum.filter(fn {score, _} -> score > threshold end)
    |> Enum.sort_by(fn {score, _} -> score end, :desc)
    |> Enum.map(fn {_score, struct} -> struct end)
  end

  @doc """
  Filters data by exact field value matches.

  Accepts a keyword list of field-value pairs and returns only structs where all non-nil values match exactly. Nil values are ignored in filtering.
  """
  @spec flag(list(struct()), keyword()) :: list(struct())
  def flag(data, fields) do
    data
    |> Enum.map(fn struct ->
      fields
      |> Enum.reject(fn {_, value} -> value == nil end)
      |> Enum.map(fn {key, value} -> Map.get(struct, key) == value end)
      |> Enum.all?()
      |> then(fn flag -> {flag, struct} end)
    end)
    |> Enum.filter(fn {flag, _} -> flag == true end)
    |> Enum.map(fn {_flag, struct} -> struct end)
  end

  @doc """
  Sorts data by a field value with date awareness.

  Sorts data by the specified field in ascending or descending order. Handles ISO 8601 date strings by parsing them for proper date-based sorting.
  """
  @spec sort(list(struct()), atom(), :asc | :desc) :: list(struct())
  def sort(data, field, order \\ :asc) do
    sign = if order == :asc, do: :lt, else: :gt
    Enum.sort(data, fn a, b -> compare_dates(Map.get(a, field), Map.get(b, field)) == sign end)
  end

  defp compare_dates(d1, d2) when is_binary(d1) and is_binary(d2) do
    case {DateTime.from_iso8601(d1), DateTime.from_iso8601(d2)} do
      {{:ok, dt1, _}, {:ok, dt2, _}} -> DateTime.compare(dt1, dt2)
      _ -> :eq
    end
  end

  defp compare_dates(_, _), do: :eq
end
