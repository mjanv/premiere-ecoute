defmodule PremiereEcoute.Models.Mistral.Supervisor do
  @moduledoc """
  Models Mistral subservice.
  """

  use PremiereEcouteCore.Supervisor,
    children: [
      # PremiereEcoute.Models.Realtime
    ]
end
