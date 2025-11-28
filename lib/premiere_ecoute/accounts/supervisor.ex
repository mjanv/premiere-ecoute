defmodule PremiereEcoute.Accounts.Supervisor do
  @moduledoc """
  Accounts subservice.

  Manages the users cache and optional services.
  """

  use Supervisor

  alias PremiereEcouteCore.Cache

  @doc """
  Starts accounts supervisor.

  Initializes users cache and optional account services under one-for-one supervision strategy.
  """
  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    mandatory = [
      {Cache, name: :users}
    ]

    optionals = []

    Supervisor.init(mandatory ++ optionals, strategy: :one_for_one)
  end
end
