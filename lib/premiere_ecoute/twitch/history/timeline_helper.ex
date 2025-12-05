defmodule PremiereEcoute.Twitch.History.TimelineHelper do
  @moduledoc """
  Helper functions for filling gaps in timeline data to ensure continuous date ranges in graphs.
  """

  @doc """
  Fills missing periods in a list of data points to create a continuous timeline.

  Takes a list of maps with date strings and a value key, and fills in any missing
  dates between the minimum and maximum dates with zero values.

  ## Parameters
    - data: List of maps with "date" keys and a value key
    - value_key: The key name for the value field (e.g., "follows", "messages")
    - period: The period type ("day", "week", "month", "year")

  ## Examples
      iex> data = [%{"date" => "2024-01", "follows" => 5}, %{"date" => "2024-03", "follows" => 3}]
      iex> fill_missing_periods(data, "follows", "month")
      [
        %{"date" => "2024-01", "follows" => 5},
        %{"date" => "2024-02", "follows" => 0},
        %{"date" => "2024-03", "follows" => 3}
      ]
  """
  def fill_missing_periods([], _value_key, _period), do: []

  def fill_missing_periods(data, value_key, period) do
    dates = Enum.map(data, & &1["date"])
    data_map = Map.new(data, fn item -> {item["date"], item[value_key]} end)

    case period do
      "day" -> fill_days(dates, data_map, value_key)
      "week" -> fill_weeks(dates, data_map, value_key)
      "month" -> fill_months(dates, data_map, value_key)
      "year" -> fill_years(dates, data_map, value_key)
    end
  end

  defp fill_days(dates, data_map, value_key) do
    # Parse dates from ISO8601 strings directly
    parsed_dates = Enum.map(dates, &Date.from_iso8601!/1)

    min_date = Enum.min(parsed_dates, Date)
    max_date = Enum.max(parsed_dates, Date)

    Date.range(min_date, max_date)
    |> Enum.map(fn date ->
      date_str = Date.to_iso8601(date)

      %{"date" => date_str}
      |> Map.put(value_key, Map.get(data_map, date_str, 0))
    end)
  end

  defp fill_weeks(dates, data_map, value_key) do
    dates
    |> parse_dates_to_date(:week)
    |> generate_date_range(:week)
    |> Enum.map(fn {year, week} ->
      date_str = "#{year}-W#{String.pad_leading(to_string(week), 2, "0")}"

      %{"date" => date_str}
      |> Map.put(value_key, Map.get(data_map, date_str, 0))
    end)
  end

  defp fill_months(dates, data_map, value_key) do
    dates
    |> parse_dates_to_date(:month)
    |> generate_date_range(:month)
    |> Enum.map(fn {year, month} ->
      date_str = "#{year}-#{String.pad_leading(to_string(month), 2, "0")}"

      %{"date" => date_str}
      |> Map.put(value_key, Map.get(data_map, date_str, 0))
    end)
  end

  defp fill_years(dates, data_map, value_key) do
    [min_year | _] = years = Enum.map(dates, &parse_year/1) |> Enum.sort()
    max_year = List.last(years)

    min_year..max_year
    |> Enum.map(fn year ->
      date_str = "#{year}"

      %{"date" => date_str}
      |> Map.put(value_key, Map.get(data_map, date_str, 0))
    end)
  end

  defp parse_dates_to_date(dates, :week) do
    Enum.map(dates, fn date_str ->
      [year_str, week_str] = String.split(date_str, "-W")
      {String.to_integer(year_str), String.to_integer(week_str)}
    end)
  end

  defp parse_dates_to_date(dates, :month) do
    Enum.map(dates, fn date_str ->
      [year_str, month_str] = String.split(date_str, "-")
      {String.to_integer(year_str), String.to_integer(month_str)}
    end)
  end

  defp generate_date_range(week_tuples, :week) do
    [{min_year, min_week} | _] = sorted = Enum.sort(week_tuples)
    {max_year, max_week} = List.last(sorted)

    generate_week_range(min_year, min_week, max_year, max_week)
  end

  defp generate_date_range(month_tuples, :month) do
    [{min_year, min_month} | _] = sorted = Enum.sort(month_tuples)
    {max_year, max_month} = List.last(sorted)

    generate_month_range(min_year, min_month, max_year, max_month)
  end

  defp generate_week_range(start_year, start_week, end_year, end_week) do
    for year <- start_year..end_year,
        week <- 1..52,
        (year > start_year or week >= start_week) and (year < end_year or week <= end_week) do
      {year, week}
    end
  end

  defp generate_month_range(start_year, start_month, end_year, end_month) do
    for year <- start_year..end_year,
        month <- 1..12,
        (year > start_year or month >= start_month) and (year < end_year or month <= end_month) do
      {year, month}
    end
  end

  defp parse_year(date_str) do
    [year_str | _] = String.split(date_str, "-")
    String.to_integer(year_str)
  end
end
