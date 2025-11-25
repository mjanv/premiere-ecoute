defmodule PremiereEcouteMock.Supervisor do
  @moduledoc """
  Premiere Ecoute Mock service. 
  
  Starts a fake Twitch API server on port 4001 with its backing state and a registry for simulated chat connections.
  """

  use Supervisor

  alias PremiereEcouteMock.TwitchApi

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      {Registry, keys: :duplicate, name: PremiereEcouteMock.ChatRegistry},
      {Bandit, plug: TwitchApi.Server, scheme: :http, port: 4001},
      TwitchApi.Backend
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
