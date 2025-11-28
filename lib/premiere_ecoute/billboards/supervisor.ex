defmodule PremiereEcoute.Billboards.Supervisor do
  @moduledoc """
  Billboards subservice.

  Manages the billboards cache.
  """

  use Supervisor

  alias PremiereEcouteCore.Cache

  @doc """
  Starts billboards supervisor with cache.

  Initializes supervisor process for billboards cache storing billboard submissions and metadata.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
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
