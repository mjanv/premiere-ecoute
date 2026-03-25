defmodule PremiereEcoute.Models.Audio.SpeechToTextWhisper do
  @moduledoc """
  Whisper speech-to-text transcription
  """

  require Logger

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  def start_link(model: model) do
    Logger.info("[#{__MODULE__}] loading model...")

    {:ok, model_info} = Bumblebee.load_model({:hf, model})
    {:ok, featurizer} = Bumblebee.load_featurizer({:hf, model})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, model})
    {:ok, generation_config} = Bumblebee.load_generation_config({:hf, model})

    serving =
      Bumblebee.Audio.speech_to_text_whisper(
        model_info,
        featurizer,
        tokenizer,
        generation_config,
        defn_options: [compiler: EXLA, client: :host]
      )

    Logger.info("[#{__MODULE__}] model loaded...")
    Nx.Serving.start_link(serving: serving, name: __MODULE__, batch_timeout: 100)
  end

  def run(samples) do
    Nx.Serving.batched_run(__MODULE__, samples)
  end
end
