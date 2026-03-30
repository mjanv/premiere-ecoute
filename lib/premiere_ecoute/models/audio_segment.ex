defmodule PremiereEcoute.Models.AudioSegment do
  @moduledoc false

  @type t :: %__MODULE__{
          id: integer(),
          start_ms: integer(),
          end_ms: integer(),
          class: :speech | :noisy,
          audio: String.t() | nil,
          text: String.t() | nil
        }

  defstruct [:id, :start_ms, :end_ms, :class, :audio, :text]

  def new(start_ms, end_ms, is_clean, audio) do
    class = if is_clean, do: :speech, else: :noisy

    %__MODULE__{
      id: System.unique_integer([:positive]),
      start_ms: round(start_ms),
      end_ms: round(end_ms),
      class: class,
      audio: audio,
      text: nil
    }
  end

  @doc """
  Decodes a segment's base64 PCM audio into an Nx tensor.

  The browser sends raw little-endian Float32 PCM at 16kHz.
  Returns a 1D `{num_samples}` tensor of type `:f32`.
  """
  def decode_audio(%__MODULE__{audio: b64} = _segment) do
    binary = Base.decode64!(b64)
    floats = for <<f::float-little-32 <- binary>>, do: f
    Nx.tensor(floats, type: :f32)
  end

  @doc """
  Wraps a segment's base64 PCM audio in a WAV container binary.

  Input is Float32 LE PCM at 16kHz mono (fmt type 3 = IEEE float).
  Returns a valid WAV binary ready to be sent to an audio API.
  """
  def to_wav(%__MODULE__{audio: b64}) do
    pcm = Base.decode64!(b64)
    num_channels = 1
    sample_rate = 16_000
    bits_per_sample = 32
    byte_rate = sample_rate * num_channels * div(bits_per_sample, 8)
    block_align = num_channels * div(bits_per_sample, 8)
    data_size = byte_size(pcm)
    chunk_size = 36 + data_size

    <<
      "RIFF",
      chunk_size::little-32,
      "WAVE",
      "fmt ",
      16::little-32,
      3::little-16,
      num_channels::little-16,
      sample_rate::little-32,
      byte_rate::little-32,
      block_align::little-16,
      bits_per_sample::little-16,
      "data",
      data_size::little-32,
      pcm::binary
    >>
  end
end
