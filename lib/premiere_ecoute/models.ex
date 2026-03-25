defmodule PremiereEcoute.Models do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Models.Audio.Segment
  alias PremiereEcoute.Models.Audio.SpeechToTextWhisper

  defdelegate new_segment(start_ms, end_ms, is_clean, audio), to: Segment, as: :new

  def run(%Segment{class: :speech, audio: audio} = segment) do
    audio
    |> Segment.decode_audio()
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
