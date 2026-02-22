defmodule PremiereEcoute.Apis.Players.Supervisor do
  @moduledoc """
  Apis Players subservice.
  """

  use PremiereEcouteCore.Supervisor,
    mandatory: [
      {Registry, keys: :unique, name: PremiereEcoute.Apis.Players.PlayerRegistry}
    ],
    optionals: [
      PremiereEcoute.Apis.PlayerSupervisor
    ]
end
