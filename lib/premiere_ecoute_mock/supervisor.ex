defmodule PremiereEcouteMock.Supervisor do
  @moduledoc false

  use Supervisor

  alias PremiereEcouteMock.TwitchApi

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      # AIDEV-NOTE: Registry for WebSocket chat message broadcasting
      {Registry, keys: :duplicate, name: PremiereEcouteMock.ChatRegistry},
      {Bandit, plug: TwitchApi.Server, scheme: :http, port: 4001},
      TwitchApi.Backend
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
