defmodule PremiereEcouteWeb.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      PremiereEcouteWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:premiere_ecoute, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PremiereEcoute.PubSub},
      PremiereEcouteWeb.Endpoint
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
