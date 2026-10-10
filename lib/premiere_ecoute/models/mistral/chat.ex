defmodule PremiereEcoute.Models.Mistral.Chat do
  @moduledoc false

  alias PremiereEcoute.Models.Mistral

  @url "https://api.mistral.ai/v1/chat/completions"

  @doc """
  Sends a chat completion request to Mistral.
  """
  @spec chat(list()) :: Req.Response.t()
  def chat(_messages) do
    Req.post!(
      @url,
      headers: Mistral.headers(:json),
      json: %{
        model: "mistral-medium-latest",
        messages: [%{role: "user", content: "Who is the most renowned French painter?"}]
      }
    )
  end
end
