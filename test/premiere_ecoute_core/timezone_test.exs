defmodule PremiereEcouteCore.TimezoneTest do
  use ExUnit.Case, async: true

  alias PremiereEcouteCore.Timezone

  describe "exists?/1" do
    test "returns true for a valid IANA timezone" do
      assert Timezone.exists?("Europe/Paris") == true
    end

    test "returns true for UTC" do
      assert Timezone.exists?("UTC") == true
    end

    test "returns false for an unknown timezone" do
      assert Timezone.exists?("Not/ATimezone") == false
    end

    test "returns false for an empty string" do
      assert Timezone.exists?("") == false
    end
  end

  describe "list/0" do
    test "returns a non-empty list" do
      assert Timezone.list() != []
    end

    test "returns a sorted list" do
      list = Timezone.list()

      assert list == Enum.sort(list)
    end

    test "contains common IANA timezones" do
      list = Timezone.list()

      assert "Europe/Paris" in list
      assert "America/New_York" in list
      assert "UTC" in list
    end

    test "returns only strings" do
      assert Timezone.list() |> Enum.all?(&is_binary/1)
    end
  end
end
