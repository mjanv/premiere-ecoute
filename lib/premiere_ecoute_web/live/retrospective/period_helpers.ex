defmodule PremiereEcouteWeb.Retrospective.PeriodHelpers do
  @moduledoc """
  Shared period navigation helpers for retrospective LiveViews.
  """

  @doc """
  Parses a year string into an integer. Returns nil if invalid or out of range.
  """
  @spec parse_year(String.t() | any()) :: integer() | nil
  def parse_year(year_str) when is_binary(year_str) do
    case Date.from_iso8601("#{year_str}-01-01") do
      {:ok, %Date{year: year}} when year >= 2020 and year <= 2030 -> year
      _ -> nil
    end
  end

  def parse_year(_), do: nil

  @doc """
  Parses a month string into an integer. Returns nil if invalid or out of range.
  """
  @spec parse_month(String.t() | any()) :: integer() | nil
  def parse_month(month_str) when is_binary(month_str) do
    case Date.from_iso8601("2024-#{String.pad_leading(month_str, 2, "0")}-01") do
      {:ok, %Date{month: month}} when month >= 1 and month <= 12 -> month
      _ -> nil
    end
  end

  def parse_month(_), do: nil

  @doc """
  Builds URL query params map for the given period, year, and month.
  """
  @spec build_params(:all | :month | :year, integer(), integer()) :: map()
  def build_params(:all, _year, _month), do: %{"period" => "all"}

  def build_params(period, year, month) do
    params = %{"period" => Atom.to_string(period), "year" => Integer.to_string(year)}

    if period == :month do
      Map.put(params, "month", Integer.to_string(month))
    else
      params
    end
  end

  @doc """
  Returns a reversed list of years from 2020 to the current year.
  """
  @spec get_available_years() :: list(integer())
  def get_available_years do
    current_year = DateTime.utc_now().year
    2020..current_year |> Enum.to_list() |> Enum.reverse()
  end
end
