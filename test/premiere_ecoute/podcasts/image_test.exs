defmodule PremiereEcoute.Podcasts.ImageTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Podcasts.Image

  defp png(width, height) do
    <<137, 80, 78, 71, 13, 10, 26, 10, 13::32, "IHDR", width::32, height::32, 0::64>>
  end

  defp jpeg(width, height) do
    app0 = <<0xFF, 0xE0, 16::16>> <> :binary.copy(<<0>>, 14)
    sof0 = <<0xFF, 0xC0, 17::16, 8, height::16, width::16>> <> :binary.copy(<<0>>, 12)
    <<0xFF, 0xD8>> <> app0 <> sof0
  end

  describe "dimensions/1" do
    test "reads PNG width and height" do
      assert Image.dimensions(png(1400, 1400)) == {:ok, {1400, 1400}}
      assert Image.dimensions(png(800, 600)) == {:ok, {800, 600}}
    end

    test "reads JPEG width and height across segments" do
      assert Image.dimensions(jpeg(1500, 1500)) == {:ok, {1500, 1500}}
    end

    test "rejects unsupported data" do
      assert {:error, :unsupported_format} = Image.dimensions("definitely not an image")
    end
  end
end
