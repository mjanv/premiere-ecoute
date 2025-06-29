defmodule PremiereEcoute.Core.Listener do
  @moduledoc false

  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    :ok = PremiereEcouteWeb.PubSub.subscribe("command_bus")
    {:ok, state}
  end

  def handle_info(command, state) do
    PremiereEcoute.apply(command)
    {:noreply, state}
  end
end
