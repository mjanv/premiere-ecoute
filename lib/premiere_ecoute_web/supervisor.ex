defmodule PremiereEcouteWeb.Supervisor do
  @moduledoc """
  Premiere Ecoute Web service

  Starts telemetry, DNS clustering, PubSub, presence tracking, and the Phoenix endpoint.
  """

  use Supervisor

  @doc """
  Starts web supervisor with telemetry, clustering, and endpoint.

  Initializes supervisor process for telemetry, DNS cluster discovery, PubSub messaging, presence tracking, and Phoenix endpoint services.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      PremiereEcouteWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:premiere_ecoute, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PremiereEcoute.PubSub},
      PremiereEcoute.Presence,
      PremiereEcouteWeb.Endpoint
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
