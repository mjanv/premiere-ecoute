defmodule PremiereEcouteCore.Supervisor do
  @moduledoc false

  use Supervisor

  alias PremiereEcouteCore.Cache

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      {Cache, name: :sessions},
      {Cache, name: :subscriptions},
      {Cache, name: :tokens},
      {Cache, name: :users}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
