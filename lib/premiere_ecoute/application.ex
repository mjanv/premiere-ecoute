defmodule PremiereEcoute.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PremiereEcouteWeb.Telemetry,
      PremiereEcoute.Repo,
      {DNSCluster, query: Application.get_env(:premiere_ecoute, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PremiereEcoute.PubSub},
      # Start a worker by calling: PremiereEcoute.Worker.start_link(arg)
      # {PremiereEcoute.Worker, arg},
      # Start to serve requests, typically the last entry
      PremiereEcouteWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PremiereEcoute.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PremiereEcouteWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
