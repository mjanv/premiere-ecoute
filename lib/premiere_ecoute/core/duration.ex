defmodule PremiereEcoute.Core.Duration do
  @moduledoc false

  def timer(nil), do: "--:--"

  def timer(duration_ms) when is_integer(duration_ms) do
    seconds = div(duration_ms, 1_000)
    "#{pad(div(seconds, 60))}:#{pad(rem(seconds, 60))}"
  end

  def timer(%DateTime{} = started_at, %DateTime{} = ended_at) do
    seconds = DateTime.diff(ended_at, started_at, :second)
    "#{div(seconds, 60)}m #{pad(rem(seconds, 60))}s"
  end

  def clock(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  def clock(_), do: "--"

  defp pad(value), do: String.pad_leading(Integer.to_string(value), 2, "0")
end
