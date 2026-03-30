defmodule PremiereEcoute.Models do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Models.AudioSegment

  @stt Application.compile_env(:premiere_ecoute, :stt, PremiereEcoute.Models.Mistral.Transcription)

  defdelegate new_audio_segment(start_ms, end_ms, is_clean, audio), to: AudioSegment, as: :new

  def transcribe(%AudioSegment{class: :speech} = segment), do: @stt.transcribe(segment)
  def transcribe(segment), do: segment
end
