defmodule PremiereEcouteWeb.Supervisor do
  @moduledoc """
  Premiere Ecoute Web service
  """

  use PremiereEcouteCore.Supervisor,
    children: [
      PremiereEcouteWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:premiere_ecoute, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PremiereEcoute.PubSub},
      PremiereEcoute.Presence,
      PremiereEcouteWeb.Endpoint
    ]
end
