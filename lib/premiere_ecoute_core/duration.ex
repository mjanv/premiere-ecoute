defmodule PremiereEcouteCore.Duration do
  @moduledoc """
  # Utilities for formatting time durations and datetime values.

  Provides functions to format millisecond durations as MM:SS timers, calculate elapsed time between datetime values, and display formatted timestamps.
  """

  @doc """
  Formats millisecond duration as MM:SS timer format.

  ## Examples

      iex> PremiereEcouteCore.Duration.timer(125_000)
      "02:05"

      iex> PremiereEcouteCore.Duration.timer("invalid")
      "--:--"
  """
  @spec timer(any()) :: String.t()
  def timer(duration_ms) when is_integer(duration_ms) do
    seconds = div(duration_ms, 1_000)
    "#{pad(div(seconds, 60))}:#{pad(rem(seconds, 60))}"
  end

  def timer(_), do: "--:--"

  @doc """
  Calculates elapsed time between two datetime values in minutes and seconds format.

  ## Examples

      iex> start_time = ~U[2024-01-01 10:00:00Z]
      iex> end_time = ~U[2024-01-01 10:03:30Z]
      iex> PremiereEcouteCore.Duration.timer(start_time, end_time)
      "3m 30s"
  """
  @spec timer(DateTime.t(), DateTime.t()) :: String.t()
  def timer(%DateTime{} = started_at, %DateTime{} = ended_at) do
    seconds = DateTime.diff(ended_at, started_at, :second)
    "#{div(seconds, 60)}m #{pad(rem(seconds, 60))}s"
  end

  def timer(_, _), do: "-"

  @doc """
  Formats millisecond duration as human-readable hours and minutes.

  Returns formatted string showing hours and minutes, minutes only, or "< 1m" for durations under one minute.
  """
  @spec duration(integer()) :: String.t()
  def duration(duration_ms) do
    total_seconds = div(duration_ms, 1000)
    hours = div(total_seconds, 3600)
    minutes = div(rem(total_seconds, 3600), 60)

    cond do
      hours > 0 -> "#{hours}h #{minutes}m"
      minutes > 0 -> "#{minutes}m"
      true -> "< 1m"
    end
  end

  @doc """
  Displays relative time from now to a past datetime.

  Returns human-readable relative time like "Just now", "5 min ago", "3 hours ago", or "2 days ago". Falls back to "--" for invalid input.
  """
  @spec ago(DateTime.t() | any()) :: String.t()
  def ago(%DateTime{} = datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      diff < 86_400 -> "#{div(diff, 3600)} hours ago"
      true -> "#{div(diff, 86400)} days ago"
    end
  end

  def ago(_), do: "--"

  defp pad(value), do: String.pad_leading(Integer.to_string(value), 2, "0")
end
