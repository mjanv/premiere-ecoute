defmodule PremiereEcoute.Core.CommandBus.Handler do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      use Gettext, backend: PremiereEcouteWeb.Gettext

      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :commands, accumulate: true)

      def validate(command), do: {:ok, command}
      def handle(_command), do: {:ok, []}

      defoverridable validate: 1, handle: 1
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def commands_or_events, do: @commands
    end
  end

  defmacro command(command) do
    quote do
      @commands unquote(command)
    end
  end

  @callback validate(struct()) :: {:ok, struct()} | {:error, any()}
  @callback handle(struct()) :: {:ok, [struct()]} | {:error, any()}
end
