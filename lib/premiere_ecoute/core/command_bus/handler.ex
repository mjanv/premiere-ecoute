defmodule PremiereEcoute.Core.CommandBus.Handler do
  @moduledoc false

  defmacro __using__(opts) do
    commands =
      opts
      |> Keyword.get(:commands, [])
      |> Enum.map(fn {_, _, command} -> Module.concat(command) end)

    events =
      opts
      |> Keyword.get(:events, [])
      |> Enum.map(fn {_, _, event} -> Module.concat(event) end)

    quote do
      @behaviour PremiereEcoute.Core.CommandBus.Handler

      for command <- unquote(commands) do
        PremiereEcoute.Core.CommandBus.Registry.register(command, __MODULE__)
      end

      for event <- unquote(events) do
        PremiereEcoute.Core.CommandBus.Registry.register(event, __MODULE__)
      end

      def validate(command), do: {:ok, command}
      def handle(_command), do: {:ok, []}
      def dispatch(_event), do: :ok

      defoverridable validate: 1, handle: 1, dispatch: 1
    end
  end

  @callback validate(struct()) :: {:ok, struct()} | {:error, any()}
  @callback handle(struct()) :: {:ok, [struct()]} | {:error, any()}
  @callback dispatch(struct()) :: :ok | {:error, any()}
end
