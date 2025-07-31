defmodule PremiereEcoute.Application do
  @moduledoc false

  use Application
  use Boundary, top_level?: true, deps: [PremiereEcoute, PremiereEcouteWeb, PremiereEcouteMock, PremiereEcouteMix, Storybook]

  @impl true
  def start(_type, _args) do
    mandatory = [
      PremiereEcouteWeb.Supervisor,
      PremiereEcoute.Supervisor
    ]

    optionals =
      case Application.get_env(:premiere_ecoute, :environment) do
        :dev -> [PremiereEcouteMock.Supervisor]
        _ -> []
      end

    Supervisor.start_link(mandatory ++ optionals, strategy: :one_for_one, name: PremiereEcoute.Application)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PremiereEcouteWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
