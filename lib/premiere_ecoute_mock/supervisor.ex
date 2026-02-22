defmodule PremiereEcouteMock.Supervisor do
  @moduledoc """
  Premiere Ecoute Mock service.

  Starts a fake Twitch API server on port 4001 with its backing state and a registry for simulated chat connections.
  """

  use Supervisor

  alias PremiereEcouteMock.TwitchApi

  @doc """
  Starts the mock service supervisor.

  Launches supervisor for mock Twitch API server, registry, and backend state management.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc false
  @spec init(term()) :: {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}}
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
