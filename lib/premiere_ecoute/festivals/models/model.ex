defmodule PremiereEcoute.Festivals.Models.Model do
  @moduledoc false

  @callback extract_festival(base64_image :: binary()) :: Enumerable.t()
end
