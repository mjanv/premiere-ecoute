defmodule PremiereEcoute.Models.Mistral do
  @moduledoc false

  alias PremiereEcoute.Models.Mistral.Chat
  alias PremiereEcoute.Models.Mistral.Moderation
  alias PremiereEcoute.Models.Mistral.Transcription

  def headers(:json) do
    [
      {"content-type", "application/json"},
      {"accept", "application/json"},
      {"authorization", "Bearer #{Application.get_env(:premiere_ecoute, :mistral)[:api_key]}"}
    ]
  end

  def headers(:multipart) do
    [
      {"accept", "application/json"},
      {"authorization", "Bearer #{Application.get_env(:premiere_ecoute, :mistral)[:api_key]}"}
    ]
  end

  def headers(_) do
    [
      {"authorization", "Bearer #{Application.get_env(:premiere_ecoute, :mistral)[:api_key]}"}
    ]
  end

  defdelegate report(messages), to: Moderation
  defdelegate chat(messages), to: Chat
  defdelegate transcribe(path), to: Transcription
end
