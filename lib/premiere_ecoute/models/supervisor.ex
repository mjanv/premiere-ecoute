defmodule PremiereEcoute.Models.Supervisor do
  @moduledoc """
  Models subservice.
  """

  use PremiereEcouteCore.Supervisor,
    children: [
      PremiereEcoute.Models.Mistral.Supervisor,
      PremiereEcoute.Models.OpenAi.Supervisor
    ]
end
