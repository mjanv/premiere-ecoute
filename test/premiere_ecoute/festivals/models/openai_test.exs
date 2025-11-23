defmodule PremiereEcoute.Festivals.Model.OpenAi do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Festivals.Models.OpenAi
  alias PremiereEcoute.Festivals.Poster

  @moduletag :skip

  setup do
    {:ok, base64} = Poster.read_base64_image("test/support/festivals/coachella.jpg")

    {:ok, %{base64: base64}}
  end

  describe "extract_festival/1" do
    test "returns one concert", %{base64: base64} do
      base64
      |> OpenAi.extract_festival()
      |> Stream.each(fn
        {:partial, festival} -> IO.puts("[Partial]: #{inspect(festival)}")
        {:ok, festival} -> IO.puts("[Final]: #{inspect(festival)}")
      end)
      |> Stream.run()

      :timer.sleep(300_000)
    end
  end
end
