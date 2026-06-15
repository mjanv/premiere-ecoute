defmodule PremiereEcoute.Podcasts.Audio.Mp3 do
  @moduledoc """
  Pure-Elixir MP3 inspection — no ffmpeg/ffprobe system dependency.

  Used by episode ingestion to extract the playback duration required for the RSS
  `<itunes:duration>` tag. The strategy mirrors the feature spec (docs/features/podcasts.md §7):

    1. Skip a leading ID3v2 tag (size read from its synchsafe header) and a trailing ID3v1 tag.
    2. Read the first valid MPEG audio frame header.
    3. If a Xing/Info (VBR) or VBRI header is present, duration is exact:
       `frame_count * samples_per_frame / sample_rate`.
    4. Otherwise assume CBR: `audio_bytes * 8 / bitrate`.

  Only MPEG Layer III ("MP3") is supported; other layers/formats return an error so ingestion
  can reject them and fall back to a manual duration.
  """

  # Samples per frame, by (version, layer). MP3 = Layer III.
  @samples_per_frame %{
    {:v1, :layer3} => 1152,
    {:v2, :layer3} => 576,
    {:v25, :layer3} => 576
  }

  # Bitrate (kbps) tables for Layer III, indexed 0..15 (0 = free, 15 = invalid).
  @bitrates_v1 {nil, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, nil}
  @bitrates_v2 {nil, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, nil}

  # Sampling rates (Hz), indexed 0..3 (3 = reserved).
  @sample_rates %{
    :v1 => {44_100, 48_000, 32_000, nil},
    :v2 => {22_050, 24_000, 16_000, nil},
    :v25 => {11_025, 12_000, 8_000, nil}
  }

  @doc """
  Returns the duration of an MP3 binary in whole seconds.

  `{:ok, seconds}` on success, `{:error, reason}` when the binary is not a parseable MP3.
  """
  @spec duration(binary()) :: {:ok, pos_integer()} | {:error, atom()}
  def duration(binary) when is_binary(binary) do
    with {:ok, audio} <- strip_tags(binary),
         {:ok, frame, header} <- first_frame(audio) do
      seconds =
        case vbr_frame_count(frame, header) do
          {:ok, frames} -> frames * header.samples_per_frame / header.sample_rate
          :error -> byte_size(audio) * 8 / (header.bitrate * 1000)
        end

      case round(seconds) do
        0 -> {:error, :zero_duration}
        n -> {:ok, n}
      end
    end
  end

  def duration(_), do: {:error, :not_binary}

  @doc "Returns true when the binary looks like an MP3 (ID3 tag or an MPEG Layer III frame)."
  @spec mp3?(binary()) :: boolean()
  def mp3?(binary) when is_binary(binary) do
    case strip_tags(binary) do
      {:ok, audio} -> match?({:ok, _, _}, first_frame(audio))
      _ -> false
    end
  end

  def mp3?(_), do: false

  # --- ID3 tag handling ---

  defp strip_tags(<<"ID3", _ver::16, flags::8, size::binary-size(4), rest::binary>>) do
    tag_size = synchsafe(size)
    footer = if Bitwise.band(flags, 0x10) != 0, do: 10, else: 0

    case rest do
      <<_skip::binary-size(^tag_size), after_tag::binary>> ->
        {:ok, strip_id3v1(after_tag) |> skip_to_footer(footer)}

      _ ->
        {:error, :truncated_id3}
    end
  end

  defp strip_tags(binary) when byte_size(binary) >= 2, do: {:ok, strip_id3v1(binary)}
  defp strip_tags(_), do: {:error, :too_short}

  # The 4 footer bytes (when present) sit right after the tag body; drop them.
  defp skip_to_footer(binary, 0), do: binary
  defp skip_to_footer(<<_::binary-size(10), rest::binary>>, 10), do: rest
  defp skip_to_footer(binary, _), do: binary

  defp strip_id3v1(binary) do
    case byte_size(binary) do
      n when n > 128 ->
        prefix = binary_part(binary, 0, n - 128)
        if binary_part(binary, n - 128, 3) == "TAG", do: prefix, else: binary

      _ ->
        binary
    end
  end

  defp synchsafe(<<b1, b2, b3, b4>>) do
    import Bitwise
    b1 <<< 21 ||| b2 <<< 14 ||| b3 <<< 7 ||| b4
  end

  # --- Frame header parsing ---

  # Scan for the first valid frame, skipping leading garbage byte-by-byte (bounded).
  defp first_frame(audio, scanned \\ 0)
  defp first_frame(_audio, scanned) when scanned > 8192, do: {:error, :no_frame}

  defp first_frame(<<0xFF, _::4, _::bitstring>> = bin, scanned) do
    case parse_header(bin) do
      {:ok, header} -> {:ok, bin, header}
      :error -> shift(bin, scanned)
    end
  end

  defp first_frame(bin, scanned), do: shift(bin, scanned)

  defp shift(<<_::8, rest::binary>>, scanned) when byte_size(rest) >= 4, do: first_frame(rest, scanned + 1)
  defp shift(_, _), do: {:error, :no_frame}

  defp parse_header(<<0xFF, 0b111::3, ver::2, layer::2, _prot::1, bitrate_i::4, rate_i::2, _pad::1, _rest::bitstring>>) do
    with {:ok, version} <- version(ver),
         {:ok, :layer3} <- layer(layer),
         spf when not is_nil(spf) <- Map.get(@samples_per_frame, {version, :layer3}),
         bitrate when not is_nil(bitrate) <- bitrate(version, bitrate_i),
         rate when not is_nil(rate) <- sample_rate(version, rate_i) do
      {:ok, %{version: version, samples_per_frame: spf, bitrate: bitrate, sample_rate: rate}}
    else
      _ -> :error
    end
  end

  defp parse_header(_), do: :error

  defp version(0b11), do: {:ok, :v1}
  defp version(0b10), do: {:ok, :v2}
  defp version(0b00), do: {:ok, :v25}
  defp version(_), do: :error

  defp layer(0b01), do: {:ok, :layer3}
  defp layer(_), do: :error

  defp bitrate(:v1, i), do: elem(@bitrates_v1, i)
  defp bitrate(_, i), do: elem(@bitrates_v2, i)

  defp sample_rate(version, i), do: @sample_rates |> Map.fetch!(version) |> elem(i)

  # --- VBR header (Xing/Info/VBRI) ---

  # AIDEV-NOTE: channel mode is the top 2 bits of the 4th header byte (not the 3rd) — getting this
  # wrong mislocates the side-info/Xing offset and silently falls back to a CBR (often 0s) estimate.
  # Side-info size determines where Xing/Info sits within the first frame; 0b11 = mono.
  defp side_info_size(:v1, <<0xFF, _::8, _::8, channel::2, _::bitstring>>), do: if(channel == 0b11, do: 17, else: 32)
  defp side_info_size(_v2, <<0xFF, _::8, _::8, channel::2, _::bitstring>>), do: if(channel == 0b11, do: 9, else: 17)

  defp vbr_frame_count(frame, header) do
    xing_offset = 4 + side_info_size(header.version, frame)

    cond do
      tag_at?(frame, xing_offset, "Xing") -> xing_frames(frame, xing_offset)
      tag_at?(frame, xing_offset, "Info") -> xing_frames(frame, xing_offset)
      tag_at?(frame, 36, "VBRI") -> vbri_frames(frame)
      true -> :error
    end
  end

  defp tag_at?(frame, offset, tag) when byte_size(frame) >= offset + 4, do: binary_part(frame, offset, 4) == tag
  defp tag_at?(_, _, _), do: false

  # Xing: "Xing"/"Info" (4) + flags (4); bit 0 of flags => frame count present (next 4 bytes).
  defp xing_frames(frame, offset) do
    case frame do
      <<_::binary-size(^offset), _tag::binary-size(4), _::24, flags::8, frames::32, _::binary>> ->
        import Bitwise
        if band(flags, 0x01) != 0, do: {:ok, frames}, else: :error

      _ ->
        :error
    end
  end

  # VBRI is at a fixed offset; frame count sits 14 bytes into the "VBRI" tag.
  defp vbri_frames(frame) do
    case frame do
      <<_::binary-size(36), "VBRI", _::binary-size(10), frames::32, _::binary>> -> {:ok, frames}
      _ -> :error
    end
  end
end
