defmodule PremiereEcoute.Discography.IsrcTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Discography.Isrc

  describe "parse/1" do
    test "read an ISRC from a string with dashes" do
      {:ok, isrc} = Isrc.parse("AA-6Q7-20-00047")

      assert isrc == %Isrc{prefix: "AA6Q7", year: 2020, designation: "00047"}
    end

    test "read an ISRC from a string without dashes" do
      {:ok, isrc} = Isrc.parse("AA6Q72000047")

      assert isrc == %Isrc{prefix: "AA6Q7", year: 2020, designation: "00047"}
    end

    test "cannot read unknown string" do
      {:error, isrc} = Isrc.parse("unknown")

      assert isrc == nil
    end
  end
end
