defmodule PremiereEcoute.Models.Mistral.Transcription do
  @moduledoc false

  @behaviour PremiereEcoute.Models.Transcription

  require Logger

  alias PremiereEcoute.Models.AudioSegment
  alias PremiereEcoute.Models.Mistral

  @url "https://api.mistral.ai/v1/audio/transcriptions"

  @impl PremiereEcoute.Models.Transcription
  def transcribe(%AudioSegment{} = segment) do
    Req.post!(
      @url,
      headers: Mistral.headers(:multipart),
      form_multipart: [
        file: {AudioSegment.to_wav(segment), filename: "audio.wav", content_type: "audio/wav"},
        model: "voxtral-mini-2507",
        language: "fr"
      ]
    )
    |> case do
      %{status: 200, body: %{"text" => text}} ->
        Logger.info("[Mistral] #{inspect(text)}")
        %{segment | text: text}

      _ ->
        segment
    end
  end
end
