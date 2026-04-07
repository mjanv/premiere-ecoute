defmodule PremiereEcoute.Apis.Players.Supervisor do
  @moduledoc """
  Apis Players subservice.
  """

  use PremiereEcouteCore.Supervisor,
    optionals: [
      {Registry, keys: :unique, name: PremiereEcoute.Apis.Players.PlayerRegistry},
      PremiereEcoute.Apis.PlayerSupervisor,
      {PremiereEcouteCore.Cache, name: :playback, persist: false}
    ]
end
