defmodule PremiereEcoute.Models.Mistral.Moderation do
  @moduledoc false

  alias PremiereEcoute.Models.Mistral

  @url "https://api.mistral.ai/v1/moderations"

  @doc """
  Asks Mistral to moderate the given messages.
  """
  @spec report(list()) :: Req.Response.t()
  def report(messages) do
    Req.post!(@url, headers: Mistral.headers(:json), json: %{model: "mistral-moderation-2411", input: messages})
  end
end
