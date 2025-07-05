defmodule PremiereEcoute.Core.CommandBus.Handler do
  @moduledoc false

  defmacro __using__(opts) do
    commands =
      opts
      |> Keyword.get(:commands, [])
      |> Enum.map(fn {_, _, command} -> Module.concat(command) end)

    quote location: :keep do
      @behaviour PremiereEcoute.Core.CommandBus.Handler

      for command <- unquote(commands) do
        PremiereEcoute.Core.Registry.register(command, __MODULE__)
      end

      def validate(command), do: {:ok, command}
      def handle(_command), do: {:ok, []}

      defoverridable validate: 1, handle: 1
    end
  end

  @callback validate(struct()) :: {:ok, struct()} | {:error, any()}
  @callback handle(struct()) :: {:ok, [struct()]} | {:error, any()}
end
