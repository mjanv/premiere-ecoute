defmodule PremiereEcoute.Wrapped.Appearance do
  @moduledoc """
  Look of a card: the cover it is tinted from and the dominant colours of that cover.

  Colours are read by downloading the cover, shrinking it and grouping its pixels in coarse RGB buckets weighted towards saturated colours. Any failure gives no colour: the page then falls back to its default palette.
  """

  import Bitwise

  @derive Jason.Encoder
  defstruct [:cover_url, colors: []]

  @type t :: %__MODULE__{cover_url: String.t() | nil, colors: [String.t()]}

  @size 32
  @max_colors 3
  @min_distance 70
  @min_brightness 48

  @doc "Returns up to 3 hex colours of the image at `url`, most dominant first."
  @spec extract(String.t() | nil) :: [String.t()]
  def extract("http" <> _ = url) do
    options = Application.get_env(:premiere_ecoute, __MODULE__, [])[:req_options] || []

    with {:ok, %{status: 200, body: body}} when is_binary(body) <- Req.get(Req.new(options), url: url, retry: false),
         {:ok, image} <- StbImage.read_binary(body, channels: 3) do
      palette(image)
    else
      _ -> []
    end
  end

  def extract(_url), do: []

  @doc "Returns up to 3 hex colours of a decoded RGB image, most dominant first."
  @spec palette(struct()) :: [String.t()]
  def palette(%StbImage{} = image) do
    %StbImage{data: data} = shrink(image)

    for(<<r, g, b <- data>>, do: {r, g, b})
    |> Enum.group_by(fn {r, g, b} -> {r >>> 5, g >>> 5, b >>> 5} end)
    |> Enum.map(fn {_bucket, pixels} -> {average(pixels), weight(pixels)} end)
    |> visible()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.reduce([], fn {color, _}, kept ->
      if length(kept) < @max_colors and Enum.all?(kept, &(distance(&1, color) >= @min_distance)), do: kept ++ [color], else: kept
    end)
    |> Enum.map(&hex/1)
  end

  # Near-black colours tint nothing: keep them only when the cover has nothing else
  defp visible(colors) do
    case Enum.reject(colors, fn {{r, g, b}, _} -> Enum.max([r, g, b]) < @min_brightness end) do
      [] -> colors
      bright -> bright
    end
  end

  defp shrink(%StbImage{shape: {h, w, _}} = image) when h > @size or w > @size, do: StbImage.resize(image, @size, @size)
  defp shrink(image), do: image

  defp average(pixels) do
    count = length(pixels)
    {r, g, b} = Enum.reduce(pixels, {0, 0, 0}, fn {r, g, b}, {sr, sg, sb} -> {sr + r, sg + g, sb + b} end)
    {div(r, count), div(g, count), div(b, count)}
  end

  # Pixel count, boosted by saturation so that a vivid accent beats a large grey area
  defp weight(pixels) do
    {r, g, b} = average(pixels)
    max = Enum.max([r, g, b])
    saturation = if max == 0, do: 0.0, else: (max - Enum.min([r, g, b])) / max
    length(pixels) * (0.4 + saturation)
  end

  defp distance({r1, g1, b1}, {r2, g2, b2}), do: abs(r1 - r2) + abs(g1 - g2) + abs(b1 - b2)

  defp hex({r, g, b}), do: "#" <> Base.encode16(<<r, g, b>>, case: :lower)
end
