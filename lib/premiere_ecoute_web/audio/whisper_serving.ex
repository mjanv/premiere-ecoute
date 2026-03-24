defmodule PremiereEcouteWeb.Audio.WhisperServing do
  @moduledoc """
  Starts an Nx.Serving for Whisper speech-to-text transcription (dev only).

  Loads openai/whisper-tiny from HuggingFace on first boot. Runs on the
  default Nx binary backend (no EXLA required).
  """

  # AIDEV-NOTE: This module is only compiled/started in :dev env.
  # The serving is registered under the name __MODULE__ and consumed by AudioLive.
  # compile/defn_options are omitted — uses the default Nx binary backend.

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent
    }
  end

  @model "openai/whisper-small"

  def start_link do
    require Logger
    Logger.info("[whisper_serving] starting...")

    {:ok, model_info} = Bumblebee.load_model({:hf, @model})
    {:ok, featurizer} = Bumblebee.load_featurizer({:hf, @model})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, @model})
    {:ok, generation_config} = Bumblebee.load_generation_config({:hf, @model})

    serving =
      Bumblebee.Audio.speech_to_text_whisper(
        model_info,
        featurizer,
        tokenizer,
        generation_config,
        defn_options: [compiler: EXLA, client: :host]
      )

    Logger.info("[whisper_serving] model loaded, starting Nx.Serving...")
    result = Nx.Serving.start_link(serving: serving, name: __MODULE__, batch_timeout: 100)
    Logger.info("[whisper_serving] Nx.Serving.start_link result=#{inspect(result)}")
    result
  end
end
