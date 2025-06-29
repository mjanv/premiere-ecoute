defmodule PremiereEcoute.Core.CommandBus do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Core.CommandBus.Registry

  def apply(command) do
    command
    |> tap(fn command -> Logger.debug("command: #{command}") end)
    |> validate()
    |> handle()
    |> tap(fn
      {:ok, events} when is_list(events) -> Enum.each(events, &dispatch/1)
      {:error, events} when is_list(events) -> Enum.each(events, &dispatch/1)
      {:error, reason} -> {:error, reason}
    end)
    |> tap(fn result -> Logger.debug("result: #{result}") end)
  end

  def validate(command) do
    case Registry.get(command.__struct__) do
      nil -> {:error, :not_registered}
      handler -> handler.validate(command)
    end
  end

  def handle({:ok, command}) do
    case Registry.get(command.__struct__) do
      nil -> {:error, :not_registered}
      handler -> handler.handle(command)
    end
  end

  def handle({:error, reason}), do: {:error, reason}

  def dispatch(event) do
    case Registry.get(event.__struct__) do
      nil -> {:error, :not_registered}
      handler -> handler.dispatch(event)
    end
  end
end
