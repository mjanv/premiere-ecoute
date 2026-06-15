defmodule PremiereEcoute.Podcasts.Image do
  @moduledoc """
  Minimal pure-Elixir image dimension reader for PNG and JPEG.

  Used to enforce Apple Podcasts' cover-art minimum (square, ≥ 1400×1400) at upload without an
  image-processing dependency. Reads only headers — never decodes pixels.
  """

  @png_magic <<137, 80, 78, 71, 13, 10, 26, 10>>

  @doc "Returns `{:ok, {width, height}}` for a supported image binary, or `{:error, reason}`."
  @spec dimensions(binary()) :: {:ok, {pos_integer(), pos_integer()}} | {:error, atom()}
  def dimensions(<<@png_magic, _len::32, "IHDR", width::32, height::32, _::binary>>), do: {:ok, {width, height}}
  def dimensions(<<0xFF, 0xD8, rest::binary>>), do: jpeg(rest)
  def dimensions(_), do: {:error, :unsupported_format}

  # Walk JPEG segments until a Start-Of-Frame marker, which carries height then width.
  defp jpeg(<<0xFF, 0xFF, rest::binary>>), do: jpeg(<<0xFF, rest::binary>>)

  defp jpeg(<<0xFF, marker, _len::16, _precision::8, height::16, width::16, _::binary>>)
       when marker in 0xC0..0xCF and marker not in [0xC4, 0xC8, 0xCC] do
    {:ok, {width, height}}
  end

  # Standalone markers (RSTn, SOI, EOI, TEM) carry no length payload.
  defp jpeg(<<0xFF, marker, rest::binary>>) when marker in 0xD0..0xD9 or marker == 0x01, do: jpeg(rest)

  defp jpeg(<<0xFF, _marker, len::16, rest::binary>>) do
    payload = len - 2

    case rest do
      <<_skip::binary-size(^payload), more::binary>> -> jpeg(more)
      _ -> {:error, :invalid_jpeg}
    end
  end

  defp jpeg(_), do: {:error, :invalid_jpeg}
end
