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

  def decode_audio(b64) do
    # Browser sends raw little-endian Float32 PCM at 16kHz.
    # Decode bytes → list of floats → Nx tensor shaped {1, num_samples}.
    binary = Base.decode64!(b64)
    floats = for <<f::float-little-32 <- binary>>, do: f
    Nx.tensor(floats, type: :f32)
  end
end
