defmodule PremiereEcoute.Apis.Supervisor do
  @moduledoc """
  Apis subservice.

  Manages caches for subscriptions and tokens, and runtime services (Twitch queue, rate limiter)
  """

  use Supervisor

  alias PremiereEcouteCore.Cache

  @doc """
  Starts APIs supervisor with caches, registry and external service clients.

  Initializes supervisor process for subscription and token caches, and optionally Twitch queue, and rate limiter outside test environment.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      {Cache, name: :subscriptions},
      {Cache, name: :tokens},
      PremiereEcoute.Apis.Players.Supervisor,
      PremiereEcoute.Apis.Streaming.Supervisor,
      PremiereEcoute.Apis.RateLimit.Supervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
