defmodule PremiereEcoute.Models.Transcription do
  @moduledoc false

  alias PremiereEcoute.Models.AudioSegment

  @callback transcribe(AudioSegment.t()) :: AudioSegment.t()
end
