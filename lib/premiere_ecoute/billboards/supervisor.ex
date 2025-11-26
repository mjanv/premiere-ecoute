defmodule PremiereEcoute.Billboards.Supervisor do
  @moduledoc """
  Billboards subservice.

  Manages the billboards cache.
  """

  use Supervisor

  alias PremiereEcouteCore.Cache

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      {Cache, name: :billboards}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
