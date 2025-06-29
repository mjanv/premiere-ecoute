defmodule PremiereEcoute.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PremiereEcouteWeb.Supervisor,
      PremiereEcoute.Supervisor
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: PremiereEcoute.Application)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PremiereEcouteWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
