defmodule PremiereEcoute.Festivals.Poster do
  @moduledoc false

  def read_base64_image(image_path) do
    with {:ok, data} <- File.read(image_path),
         mime_type <- image_path |> Path.extname() |> String.downcase() |> mime_type() do
      {:ok, "data:#{mime_type};base64,#{Base.encode64(data)}"}
    else
      {:error, reason} -> {:error, "Error encoding image: #{inspect(reason)}"}
    end
  end

  defp mime_type(".jpg"), do: "image/jpeg"
  defp mime_type(".jpeg"), do: "image/jpeg"
  defp mime_type(".png"), do: "image/png"
  defp mime_type(_), do: "image/jpeg"
end
