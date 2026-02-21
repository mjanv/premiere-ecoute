defmodule PremiereEcoute.Apis.RateLimit.Supervisor do
  @moduledoc """
  Apis Rate limit subservice.
  """

  use Supervisor

  import Cachex.Spec

  alias PremiereEcoute.Apis.RateLimit
  alias PremiereEcouteCore.Cache

  @doc false
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    mandatory = []

    optionals =
      case Application.get_env(:premiere_ecoute, :environment) do
        :test ->
          []

        _ ->
          [
            {Cache, name: :rate_limits, hooks: [hook(module: RateLimit.CircuitBreakerMonitor)]},
            RateLimit.RateLimiter
          ]
      end

    Supervisor.init(mandatory ++ optionals, strategy: :one_for_one)
  end
end
