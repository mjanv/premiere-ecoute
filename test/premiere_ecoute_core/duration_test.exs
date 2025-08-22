defmodule PremiereEcouteCore.DurationTest do
  use ExUnit.Case, async: true

  alias PremiereEcouteCore.Duration

  describe "timer/1" do
    test "returns an empty timer for undefined values" do
      assert Duration.timer(nil) == "--:--"
    end

    test "returns a valid timer for duration in milliseconds" do
      assert Duration.timer(0) == "00:00"
      assert Duration.timer(14_567) == "00:14"
      assert Duration.timer((10 * 60 + 37) * 1_000) == "10:37"
      assert Duration.timer((999 * 60 + 17) * 1_000) == "999:17"
    end

    test "returns a valid timer for datetime range" do
      {:ok, start_datetime} = DateTime.new(~D[2025-07-22], ~T[14:30:00], "Etc/UTC")
      end_datetime = DateTime.add(start_datetime, 270, :second)

      assert Duration.timer(start_datetime, end_datetime) == "4m 30s"
    end
  end

  describe "duration/1" do
    test "returns hours and minutes when > 1h" do
      assert Duration.duration((2 * 3600 + 15 * 60) * 1000) == "2h 15m"
    end

    test "returns only minutes when < 1h" do
      assert Duration.duration(45 * 60 * 1000) == "45m"
    end

    test "returns < 1m when under a minute" do
      assert Duration.duration(30 * 1000) == "< 1m"
    end

    test "rounds down to minutes" do
      assert Duration.duration((1 * 3600 + 59 * 60 + 59) * 1000) == "1h 59m"
    end
  end

  describe "ago/1" do
    setup do
      now = DateTime.utc_now()

      {:ok, %{now: now}}
    end

    test "return an empty timer for undefined values" do
      assert Duration.ago(nil) == "--"
    end

    test "return a just timer when the datetime is less than one minute away", %{now: now} do
      datetime = DateTime.add(now, -5, :second)

      assert Duration.ago(datetime) == "Just now"
    end

    test "return a minute timer when the datetime is less than an hour away", %{now: now} do
      datetime = DateTime.add(now, -25, :minute)

      assert Duration.ago(datetime) == "25 min ago"
    end

    test "return a hour timer when the datetime is less than 24 hours away", %{now: now} do
      datetime = DateTime.add(now, -16, :hour)

      assert Duration.ago(datetime) == "16 hours ago"
    end

    test "return a day timer when the datetime is more than 24 hours away", %{now: now} do
      datetime = DateTime.add(now, -36, :hour)

      assert Duration.ago(datetime) == "1 days ago"
    end
  end
end
