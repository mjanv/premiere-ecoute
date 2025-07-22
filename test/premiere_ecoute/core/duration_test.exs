defmodule PremiereEcoute.Core.DurationTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Core.Duration

  describe "timer/1" do
    test "returns an empty timer for undefined values" do
      assert Duration.timer(nil) == "--:--"
    end

    test "returns a valid timer for duration in milliseconds" do
      assert Duration.timer(0) == "00:00"
      assert Duration.timer(14567) == "00:14"
      assert Duration.timer((10 * 60 + 37) * 1_000) == "10:37"
      assert Duration.timer((999 * 60 + 17) * 1_000) == "999:17"
    end

    test "returns a valid timer for datetime range" do
      {:ok, start_datetime} = DateTime.new(~D[2025-07-22], ~T[14:30:00], "Etc/UTC")
      end_datetime = DateTime.add(start_datetime, 270, :second)

      assert Duration.timer(start_datetime, end_datetime) == "4m 30s"
    end
  end

  describe "clock/1" do
    test "returns an empty clock for undefined values" do
      assert Duration.clock(nil) == "--"
    end

    test "returns a valid clock for valid datetimes" do
      {:ok, datetime} = DateTime.new(~D[2025-07-22], ~T[14:30:45], "Etc/UTC")

      assert Duration.clock(datetime) == "Jul 22, 2025 at 02:30 PM"
    end
  end
end
