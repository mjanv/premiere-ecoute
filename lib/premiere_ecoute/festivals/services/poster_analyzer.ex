defmodule PremiereEcoute.Festivals.Services.PosterAnalyzer do
  @moduledoc false

  alias PremiereEcoute.Festivals.Poster
  alias PremiereEcoute.PubSub

  @model Application.compile_env(:premiere_ecoute, [PremiereEcoute.Festivals, :model])

  def analyze_poster(scope, image_path) do
    with {:ok, base64} <- Poster.read_base64_image(image_path),
         stream <- @model.extract_festival(base64),
         stream <- broadcast(stream, scope) do
      stream |> Stream.take(-1) |> Enum.to_list() |> hd()
    end
  end

  defp broadcast(stream, scope) do
    Stream.each(stream, fn
      {:partial, festival} -> PubSub.broadcast("festival:#{scope.user.id}", {:partial, festival})
      {:ok, _} -> :ok
    end)
  end
end
