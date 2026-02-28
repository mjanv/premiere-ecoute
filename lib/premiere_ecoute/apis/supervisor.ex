defmodule PremiereEcoute.Apis.Supervisor do
  @moduledoc """
  Apis subservice.
  """

  use PremiereEcouteCore.Supervisor,
    children: [
      {PremiereEcouteCore.Cache, name: :subscriptions, persist: true},
      {PremiereEcouteCore.Cache, name: :tokens, persist: true},
      PremiereEcoute.Apis.Players.Supervisor,
      PremiereEcoute.Apis.MusicProvider.Supervisor,
      PremiereEcoute.Apis.Streaming.Supervisor,
      PremiereEcoute.Apis.RateLimit.Supervisor
    ]
end
