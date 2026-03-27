defmodule PremiereEcoute.Models do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Models.AudioSegment
  alias PremiereEcoute.Models.OpenAi.SpeechToTextWhisper

  defdelegate new_audio_segment(start_ms, end_ms, is_clean, audio), to: AudioSegment, as: :new

  def run(%AudioSegment{class: :speech, audio: audio} = segment) do
    audio
    |> AudioSegment.decode_audio()
    |> SpeechToTextWhisper.run()
    |> case do
      %{chunks: [%{text: text} | _]} ->
        Logger.info("[whisper] text=#{inspect(text)}")
        %{segment | text: String.trim(text)}

      _ ->
        segment
    end
  end

  def run(segment), do: segment
end
