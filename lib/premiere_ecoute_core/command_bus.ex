defmodule PremiereEcouteCore.CommandBus do
  @moduledoc false

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
