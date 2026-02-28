defmodule PremiereEcoute.Festivals.PosterTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Festivals.Poster

  describe "read_base64_image/1" do
    test "can read a base64 image from a JPG file" do
      {:ok, base64} = Poster.read_base64_image("test/support/festivals/coachella.jpg")

      assert base64 =~ "Tmq5hWLFzhfLUIyMidd2TTFMoifewYvs5PLLjqM0m1c53HPrmom+9nue9HMOwyd5XbzAONoP5daesUIxG25TnJJ"
    end
  end
end
