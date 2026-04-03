defmodule PremiereEcoute.Models.OpenAi.Supervisor do
  @moduledoc """
  Models OpenAI subservice.
  """

  use PremiereEcouteCore.Supervisor,
    children: [
      # {PremiereEcoute.Models.OpenAi.SpeechToTextWhisper, [model: "openai/whisper-tiny"]}
    ]
end
