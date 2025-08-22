defmodule PremiereEcouteCore.DateTest do
  use ExUnit.Case, async: true

  alias PremiereEcouteCore.Date

  describe "date/1" do
    test "returns an empty date for undefined values" do
      assert Date.date(nil) == "-"
    end

    test "return a valid string for a datetime" do
      datetime = ~U[2021-01-12 00:01:00.00Z]

      assert Date.date(datetime) == "Jan 12, 2021"
    end

    test "return a valid string for a naive datetime" do
      datetime = ~N[2021-02-12 00:01:00.00]

      assert Date.date(datetime) == "Feb 12, 2021"
    end

    test "return a valid string for an ISO8601 string datetime" do
      datetime = "2021-08-21T18:42:13Z"

      assert Date.date(datetime) == "Aug 21, 2021"
    end
  end

  describe "datetime/1" do
    test "returns an empty date for undefined values" do
      assert Date.datetime(nil) == "-"
    end

    test "return a valid string for a datetime" do
      datetime = ~U[2021-01-12 00:01:00.00Z]

      assert Date.datetime(datetime) == "Jan 12, 2021 at 12:01 AM"
    end

    test "return a valid string for a naive datetime" do
      datetime = ~N[2021-02-12 00:01:00.00]

      assert Date.datetime(datetime) == "Feb 12, 2021 at 12:01 AM"
    end

    test "return a valid string for an ISO8601 string datetime" do
      datetime = "2021-08-21T18:42:13Z"

      assert Date.datetime(datetime) == "Aug 21, 2021 at 06:42 PM"
    end
  end
end
