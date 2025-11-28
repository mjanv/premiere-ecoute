defmodule PremiereEcoute.Events.Supervisor do
  @moduledoc """
  Event sourcing subservice.

  Manages the event store.
  """

  use Supervisor

  @doc """
  Starts event sourcing supervisor with event store.

  Initializes supervisor process for event store managing domain events persistence and retrieval.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      PremiereEcoute.Events.Store
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
