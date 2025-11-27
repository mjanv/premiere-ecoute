defmodule PremiereEcouteCore.EventBus.Handler do
  @moduledoc """
  Base module for event handlers.

  Provides event registration and default implementation for event dispatching. Handlers must declare which events they handle using the `event/1` macro and implement the `dispatch/1` callback.

  ## Usage

      defmodule MyEventHandler do
        use PremiereEcouteCore.EventBus.Handler

        event MyEvent

        def dispatch(%MyEvent{} = evt) do
          # Handle the event
          IO.inspect(evt)
          :ok
        end
      end
  """

  @doc """
  Injects event handler functionality into using module.

  Registers event attributes, provides default dispatch implementation, and sets up Gettext integration.
  """
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

  @doc """
  Finalizes event handler compilation.

  Generates commands_or_events function returning registered event modules.
  """
  defmacro __before_compile__(_env) do
    quote do
      def commands_or_events, do: @events
    end
  end

  @doc """
  Registers event module for handler.

  Declares which event this handler processes. Can be called multiple times for multiple events.
  """
  defmacro event(event) do
    quote do
      @events unquote(event)
    end
  end

  @callback dispatch(struct()) :: :ok | {:error, any()}
end
