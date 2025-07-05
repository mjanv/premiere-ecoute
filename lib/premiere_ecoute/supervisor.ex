defmodule PremiereEcoute.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      PremiereEcoute.PromEx,
      PremiereEcoute.Repo,
      PremiereEcoute.Apis.Supervisor,
      Supervisor.child_spec({Cachex, name: :cache}, id: :cache1),
      Supervisor.child_spec({Cachex, name: :polls}, id: :cache2)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
