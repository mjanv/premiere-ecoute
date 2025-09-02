defmodule PremiereEcoute.Apis.Supervisor do
  @moduledoc false

  use Supervisor

  alias PremiereEcouteCore.Cache

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      {Cache, name: :subscriptions},
      {Cache, name: :tokens},
      PremiereEcoute.Apis.PlayerSupervisor,
      {Registry, keys: :unique, name: PremiereEcoute.Apis.PlayerRegistry}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
