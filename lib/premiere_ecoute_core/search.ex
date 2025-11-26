defmodule PremiereEcouteCore.Search do
  @moduledoc """
  Search and filtering utilities.

  Provides functions for fuzzy text search using Jaro distance, field-based filtering, and date-aware sorting of data collections.
  """

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
