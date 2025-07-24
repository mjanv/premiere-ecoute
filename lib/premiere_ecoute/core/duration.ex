defmodule PremiereEcoute.Core.Duration do
  @moduledoc """
  # Utilities for formatting time durations and datetime values.

  Provides functions to format millisecond durations as MM:SS timers, calculate elapsed time between datetime values, and display formatted timestamps.
  """

  @doc """
  Formats millisecond duration as MM:SS timer format.

  ## Examples

      iex> PremiereEcoute.Core.Duration.timer(125_000)
      "02:05"

      iex> PremiereEcoute.Core.Duration.timer("invalid")
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

      iex> start = ~U[2024-01-01 10:00:00Z]
      iex> end_time = ~U[2024-01-01 10:03:30Z]
      iex> PremiereEcoute.Core.Duration.timer(start, end_time)
      "3m 30s"
  """
  @spec timer(DateTime.t(), DateTime.t()) :: String.t()
  def timer(%DateTime{} = started_at, %DateTime{} = ended_at) do
    seconds = DateTime.diff(ended_at, started_at, :second)
    "#{div(seconds, 60)}m #{pad(rem(seconds, 60))}s"
  end

  @doc """
  Formats datetime as a human-readable timestamp.

  ## Examples

      iex> dt = ~U[2024-03-15 14:30:00Z]
      iex> PremiereEcoute.Core.Duration.clock(dt)
      "Mar 15, 2024 at 02:30 PM"

      iex> PremiereEcoute.Core.Duration.clock("invalid")
      "--"
  """
  @spec clock(any()) :: String.t()
  def clock(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  def clock(_), do: "--"

  defp pad(value), do: String.pad_leading(Integer.to_string(value), 2, "0")
end
