defmodule PremiereEcoute.Apis.RateLimit.Supervisor do
  @moduledoc """
  Apis Rate limit subservice.
  """

  import Cachex.Spec

  use PremiereEcouteCore.Supervisor,
    optionals: [
      {PremiereEcouteCore.Cache, name: :rate_limits, hooks: [hook(module: PremiereEcoute.Apis.RateLimit.CircuitBreakerMonitor)]},
      PremiereEcoute.Apis.RateLimit.RateLimiter
    ]
end
