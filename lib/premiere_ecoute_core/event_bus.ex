defmodule PremiereEcouteCore.EventBus do
  @moduledoc """
  Event bus for event-driven architecture.

  Dispatches domain events to registered handlers for processing. Handlers must be registered in the Registry for their event types. Supports dispatching single events or lists of events.

  ## Usage

      EventBus.dispatch(%MyEvent{field: "value"})
      EventBus.dispatch([%Event1{}, %Event2{}])
  """

  require Logger

  alias PremiereEcouteCore.Registry

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
