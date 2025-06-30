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

    quote location: :keep do
      @commands unquote(commands)
      @events unquote(events)

      @behaviour PremiereEcoute.Core.CommandBus.Handler
      @before_compile PremiereEcoute.Core.CommandBus.Handler

      def validate(command), do: {:ok, command}
      def handle(_command), do: {:ok, []}
      def dispatch(_event), do: :ok

      defoverridable validate: 1, handle: 1, dispatch: 1
    end
  end

  defmacro __before_compile__(env) do
    commands = Module.get_attribute(env.module, :commands)
    events = Module.get_attribute(env.module, :events)

    for command <- commands do
      PremiereEcoute.Core.CommandBus.Registry.register(command, env.module)
    end

    for event <- events do
      PremiereEcoute.Core.CommandBus.Registry.register(event, env.module)
    end

    quote do
    end
  end

  @callback validate(struct()) :: {:ok, struct()} | {:error, any()}
  @callback handle(struct()) :: {:ok, [struct()]} | {:error, any()}
  @callback dispatch(struct()) :: :ok | {:error, any()}
end
