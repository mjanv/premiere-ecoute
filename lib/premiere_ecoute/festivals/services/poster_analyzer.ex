defmodule PremiereEcoute.Festivals.Services.PosterAnalyzer do
  @moduledoc """
  Festival poster analysis service.

  Analyzes festival poster images using configured AI model, broadcasts partial results via PubSub for real-time UI updates, and returns complete festival data.
  """

  alias PremiereEcoute.Festivals.Poster
  alias PremiereEcoute.PubSub

  @model Application.compile_env(:premiere_ecoute, [PremiereEcoute.Festivals, :model])

  @doc """
  Analyzes festival poster image and extracts data.

  Reads image, extracts festival data using AI model, broadcasts partial results to user via PubSub, and returns final festival data.
  """
  @spec analyze_poster(PremiereEcoute.Accounts.Scope.t(), String.t()) ::
          {:ok, PremiereEcoute.Festivals.Festival.t()} | {:error, String.t()}
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
