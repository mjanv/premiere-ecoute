defmodule PremiereEcoute.Apis.Supervisor do
  @moduledoc """
  Apis subservice.

  Manages caches for subscriptions and tokens, a player registry, and runtime services (player supervisor, Twitch queue, rate limiter)
  """

  use Supervisor

  alias PremiereEcouteCore.Cache

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    mandatory = [
      {Cache, name: :subscriptions},
      {Cache, name: :tokens},
      {Registry, keys: :unique, name: PremiereEcoute.Apis.PlayerRegistry}
    ]

    optionals =
      case Application.get_env(:premiere_ecoute, :environment) do
        :test ->
          []

        _ ->
          [
            PremiereEcoute.Apis.PlayerSupervisor,
            PremiereEcoute.Apis.TwitchQueue,
            PremiereEcoute.Apis.RateLimit
          ]
      end

    Supervisor.init(mandatory ++ optionals, strategy: :one_for_one)
  end
end
