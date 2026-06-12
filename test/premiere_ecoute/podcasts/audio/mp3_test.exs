defmodule PremiereEcoute.Podcasts.Audio.Mp3Test do
  use ExUnit.Case, async: true

  import Bitwise

  alias PremiereEcoute.Podcasts.Audio.Mp3

  # --- Helpers that assemble real MPEG audio bytes so the parser is exercised end-to-end ---

  # MPEG-1 Layer III header. byte2 = 0xFB (sync 111, version 11=v1, layer 01=LIII, protection 1).
  defp v1_header(bitrate_idx, rate_idx \\ 0, channel \\ 0b00, pad \\ 0) do
    b3 = bitrate_idx <<< 4 ||| rate_idx <<< 2 ||| pad <<< 1
    b4 = channel <<< 6
    <<0xFF, 0xFB, b3, b4>>
  end

  # MPEG-2 Layer III header. byte2 = 0xF3 (sync 111, version 10=v2, layer 01=LIII, protection 1).
  defp v2_header(bitrate_idx, rate_idx \\ 0, channel \\ 0b11) do
    b3 = bitrate_idx <<< 4 ||| rate_idx <<< 2
    b4 = channel <<< 6
    <<0xFF, 0xF3, b3, b4>>
  end

  # A constant-bitrate frame: header + zero padding up to the computed frame length.
  defp cbr_frame(bitrate_idx, bitrate_kbps, samplerate \\ 44_100) do
    frame_len = trunc(144 * bitrate_kbps * 1000 / samplerate)
    v1_header(bitrate_idx) <> :binary.copy(<<0>>, frame_len - 4)
  end

  defp id3v2(body_size) do
    <<"ID3", 3, 0, 0, 0, 0, 0, body_size>> <> :binary.copy(<<0>>, body_size)
  end

  describe "duration/1 — CBR" do
    test "computes duration from bitrate and byte size (128kbps)" do
      audio = :binary.copy(cbr_frame(9, 128), 200)
      expected = round(byte_size(audio) * 8 / 128_000)

      assert {:ok, ^expected} = Mp3.duration(audio)
    end

    test "ignores a leading ID3v2 tag" do
      audio = :binary.copy(cbr_frame(9, 128), 200)
      with_tag = id3v2(60) <> audio

      assert Mp3.duration(with_tag) == Mp3.duration(audio)
    end

    test "ignores a trailing ID3v1 tag" do
      audio = :binary.copy(cbr_frame(9, 128), 200)
      id3v1 = "TAG" <> :binary.copy(<<0>>, 125)

      assert Mp3.duration(audio <> id3v1) == Mp3.duration(audio)
    end
  end

  describe "duration/1 — VBR (Xing/Info)" do
    test "uses exact frame count for MPEG-1 stereo" do
      # stereo side info = 32 bytes, Xing sits at offset 4 + 32 = 36.
      frames = 5000
      xing = "Xing" <> <<0, 0, 0, 0x01>> <> <<frames::32>>
      frame = v1_header(9) <> :binary.copy(<<0>>, 32) <> xing <> :binary.copy(<<0>>, 100)

      assert {:ok, duration} = Mp3.duration(frame)
      assert duration == round(frames * 1152 / 44_100)
    end

    test "accepts the 'Info' tag (CBR-encoded VBR header) too" do
      frames = 1000
      info = "Info" <> <<0, 0, 0, 0x01>> <> <<frames::32>>
      frame = v1_header(9) <> :binary.copy(<<0>>, 32) <> info <> :binary.copy(<<0>>, 100)

      assert {:ok, duration} = Mp3.duration(frame)
      assert duration == round(frames * 1152 / 44_100)
    end

    test "uses exact frame count for MPEG-2 mono (576 samples/frame)" do
      # mono v2 side info = 9 bytes, Xing sits at offset 4 + 9 = 13.
      frames = 3000
      xing = "Xing" <> <<0, 0, 0, 0x01>> <> <<frames::32>>
      frame = v2_header(9) <> :binary.copy(<<0>>, 9) <> xing <> :binary.copy(<<0>>, 100)

      assert {:ok, duration} = Mp3.duration(frame)
      assert duration == round(frames * 576 / 22_050)
    end
  end

  describe "duration/1 — errors" do
    test "rejects non-MP3 bytes" do
      assert {:error, _} = Mp3.duration(:binary.copy(<<0>>, 200))
    end

    test "rejects a non-binary input" do
      assert {:error, :not_binary} = Mp3.duration(123)
    end
  end

  describe "mp3?/1" do
    test "true for a real frame" do
      assert Mp3.mp3?(:binary.copy(cbr_frame(9, 128), 10))
    end

    test "false for arbitrary text" do
      refute Mp3.mp3?("this is definitely not an mp3 file")
    end
  end
end
