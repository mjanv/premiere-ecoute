defmodule PremiereEcouteCore.CommandBus do
  @moduledoc """
  Command bus for CQRS pattern implementation.

  Orchestrates command processing by validating commands, delegating to registered handlers, and dispatching resulting events to the EventBus. Handlers must be registered in the Registry for their command types.

  ## Workflow

  1. Command is validated through its registered handler
  2. Valid commands are executed through the handler
  3. Resulting events are dispatched to the EventBus
  4. Returns either `{:ok, entity, events}`, `{:ok, events}`, or `{:error, reason}`

  ## Usage

      CommandBus.apply(%MyCommand{field: "value"})
  """

  require Logger

  alias PremiereEcouteCore.EventBus
  alias PremiereEcouteCore.Registry

  def apply(command) do
    command
    |> tap(fn command -> Logger.debug("command: #{inspect(command)}") end)
    |> validate()
    |> handle()
    |> tap(fn
      {:ok, entity, events} when is_list(events) ->
        EventBus.dispatch(events)
        {:ok, entity, events}

      {:ok, events} when is_list(events) ->
        EventBus.dispatch(events)
        {:ok, events}

      {:error, events} when is_list(events) ->
        EventBus.dispatch(events)
        {:error, events}

      {:error, reason} ->
        {:error, reason}
    end)
    |> tap(fn result -> Logger.debug("result: #{inspect(result)}") end)
  end

  def validate(command) do
    case Registry.get(command.__struct__) do
      nil ->
        Logger.error("No registered handler for #{inspect(command.__struct__)}")
        {:error, :not_registered}

      handler ->
        handler.validate(command)
    end
  end

  def handle({:ok, command}) do
    case Registry.get(command.__struct__) do
      nil ->
        Logger.error("No registered handler for #{inspect(command.__struct__)}")
        {:error, :not_registered}

      handler ->
        handler.handle(command)
    end
  end

  def handle({:error, reason}), do: {:error, reason}
end
