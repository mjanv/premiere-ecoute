defmodule PremiereEcouteCore.Date do
  @moduledoc false

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
