defmodule PremiereEcoute.Apis.Streaming.Supervisor do
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
    childrens = [
      PremiereEcoute.Apis.Streaming.TwitchQueue
    ]

    Supervisor.init(childrens, strategy: :one_for_one)
  end
end
