defmodule PremiereEcoute.Festivals.Models.Model do
  @moduledoc """
  Festival poster analysis model behaviour.

  Defines callback for extracting festival information from base64-encoded poster images using AI.
  """

  @callback extract_festival(base64_image :: binary()) :: Enumerable.t()
end
