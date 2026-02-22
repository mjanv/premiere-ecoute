defmodule PremiereEcoute.Apis.Supervisor do
  @moduledoc """
  Apis subservice.
  """

  use PremiereEcouteCore.Supervisor,
    children: [
      {PremiereEcouteCore.Cache, name: :subscriptions},
      {PremiereEcouteCore.Cache, name: :tokens},
      PremiereEcoute.Apis.Players.Supervisor,
      PremiereEcoute.Apis.Streaming.Supervisor,
      PremiereEcoute.Apis.RateLimit.Supervisor
    ]
end
