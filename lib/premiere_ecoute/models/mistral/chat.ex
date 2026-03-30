defmodule PremiereEcoute.Models.Mistral.Chat do
  @moduledoc false

  alias PremiereEcoute.Models.Mistral

  @url "https://api.mistral.ai/v1/chat/completions"

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
