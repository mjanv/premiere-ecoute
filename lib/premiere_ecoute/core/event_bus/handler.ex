defmodule PremiereEcoute.Core.EventBus.Handler do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      use Gettext, backend: PremiereEcoute.Gettext

      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :events, accumulate: true)

      def dispatch(_event), do: :ok

      defoverridable dispatch: 1
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def commands_or_events, do: @events
    end
  end

  defmacro event(event) do
    quote do
      @events unquote(event)
    end
  end

  @callback dispatch(struct()) :: :ok | {:error, any()}
end
