defmodule PremiereEcoute.Core.EventBus do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Core.Registry

  def dispatch([]), do: :ok

  def dispatch([event | events]) do
    dispatch(event)
    dispatch(events)
  end

  def dispatch(event) do
    case Registry.get(event.__struct__) do
      nil ->
        Logger.error("No registered handler for #{inspect(event.__struct__)}")
        {:error, :not_registered}

      handler ->
        handler.dispatch(event)
    end
  end
end
