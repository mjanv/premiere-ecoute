defmodule PremiereEcoute.Models do
  @moduledoc false

  use PremiereEcouteCore.Context

  alias PremiereEcoute.Models.AudioSegment

  @stt Application.compile_env(:premiere_ecoute, :stt, PremiereEcoute.Models.Mistral.Transcription)

  defdelegate new_audio_segment(start_ms, end_ms, is_clean, audio), to: AudioSegment, as: :new

  @doc """
  Transcribes a speech segment with the configured speech-to-text model. Noisy segments are returned untouched.
  """
  @spec transcribe(AudioSegment.t()) :: AudioSegment.t()
  def transcribe(%AudioSegment{class: :speech} = segment), do: @stt.transcribe(segment)
  def transcribe(segment), do: segment
end
