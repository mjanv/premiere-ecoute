defmodule PremiereEcoute.Events.Supervisor do
  @moduledoc """
  Event sourcing subservice.
  """

  use PremiereEcouteCore.Supervisor,
    children: [
      PremiereEcoute.Events.Store
    ]
end
