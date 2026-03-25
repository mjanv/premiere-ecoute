defmodule PremiereEcoute.Models.Supervisor do
  @moduledoc """
  Models subservice.
  """

  use PremiereEcouteCore.Supervisor,
    children: [
      {PremiereEcoute.Models.Audio.SpeechToTextWhisper, [model: "openai/whisper-tiny"]}
    ]
end
