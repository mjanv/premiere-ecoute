defmodule PremiereEcoute.Apis.Players.Supervisor do
  @moduledoc """
  Apis Players subservice.
  """

  use Supervisor

  @doc false
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    mandatory = [
      {Registry, keys: :unique, name: PremiereEcoute.Apis.Players.PlayerRegistry}
    ]

    optionals =
      case Application.get_env(:premiere_ecoute, :environment) do
        :test -> []
        _ -> [PremiereEcoute.Apis.PlayerSupervisor]
      end

    Supervisor.init(mandatory ++ optionals, strategy: :one_for_one)
  end
end
