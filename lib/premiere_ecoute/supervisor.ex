defmodule PremiereEcoute.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      PremiereEcoute.Telemetry.PromEx,
      PremiereEcoute.Repo,
      PremiereEcoute.EventStore,
      PremiereEcoute.Core.Supervisor,
      {Oban, Application.fetch_env!(:premiere_ecoute, Oban)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
