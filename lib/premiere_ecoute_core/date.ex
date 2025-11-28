defmodule PremiereEcouteCore.Date do
  @moduledoc """
  Date and datetime formatting utilities.

  Provides functions to format dates and datetimes into human-readable strings, handling Date, DateTime, NaiveDateTime, and ISO8601 string inputs.
  """

  @doc """
  Formats date or datetime into human-readable date string.

  Accepts Date, DateTime, NaiveDateTime, or ISO8601 string. Returns formatted date as "MMM DD, YYYY" or "-" for invalid inputs.
  """
  @spec date(Date.t() | DateTime.t() | NaiveDateTime.t() | String.t() | any()) :: String.t()
  def date(%Date{} = date) do
    Calendar.strftime(date, "%b %d, %Y")
  end

  def date(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  def date(%NaiveDateTime{} = naive_datetime) do
    date(DateTime.from_naive!(naive_datetime, "Etc/UTC"))
  end

  def date(iso8601_datetime) when is_binary(iso8601_datetime) do
    iso8601_datetime
    |> NaiveDateTime.from_iso8601()
    |> case do
      {:ok, naive_datetime} -> naive_datetime
      _ -> nil
    end
    |> date()
  end

  def date(_), do: "-"

  @doc """
  Formats datetime into human-readable datetime string.

  Accepts DateTime, NaiveDateTime, or ISO8601 string. Returns formatted datetime as "MMM DD, YYYY at HH:MM AM/PM" or "-" for invalid inputs.
  """
  @spec datetime(DateTime.t() | NaiveDateTime.t() | String.t() | any()) :: String.t()
  def datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  def datetime(%NaiveDateTime{} = naive_datetime) do
    datetime(DateTime.from_naive!(naive_datetime, "Etc/UTC"))
  end

  def datetime(iso8601_datetime) when is_binary(iso8601_datetime) do
    iso8601_datetime
    |> NaiveDateTime.from_iso8601()
    |> case do
      {:ok, naive_datetime} -> naive_datetime
      _ -> nil
    end
    |> datetime()
  end

  def datetime(_), do: "-"
end
