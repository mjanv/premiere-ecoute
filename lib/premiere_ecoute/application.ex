defmodule PremiereEcoute.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PremiereEcouteWeb.Telemetry,
      PremiereEcoute.Repo,
      {DNSCluster, query: Application.get_env(:premiere_ecoute, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PremiereEcoute.PubSub},
      PremiereEcouteWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: PremiereEcoute.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PremiereEcouteWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
