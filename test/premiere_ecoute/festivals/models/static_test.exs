defmodule PremiereEcoute.Festivals.Model.StaticTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Festivals.Festival
  alias PremiereEcoute.Festivals.Models.Static

  describe "extract_festival/1" do
    test "returns one festival" do
      stream = Static.extract_festival("1")

      [_, _, {:ok, festival}] = Enum.to_list(stream)

      assert festival == %Festival{
               name: "Awesome",
               start_date: nil,
               end_date: nil,
               concerts: [%Festival.Concert{artist: "Sabrina Carpenter", date: ~D[2025-01-04]}]
             }
    end
  end
end
