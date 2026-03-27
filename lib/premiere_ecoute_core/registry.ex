defmodule PremiereEcouteCore.Registry do
  @moduledoc """
  Handler registry for commands and events.

  Maintains a compile-time registry of command and event handlers configured in the application. Handlers are looked up by matching command or event modules to their registered handlers.

  ## Configuration

  Handlers must be configured in application config:

      config :premiere_ecoute, :handlers, [
        MyApp.Handlers.UserHandler,
        MyApp.Handlers.OrderHandler
      ]

  Each handler must implement `commands_or_events/0` returning a list of command/event modules it handles.
  """

  require Logger

  def init do
    for h <- Application.get_env(:premiere_ecoute, :handlers, []) do
      case Code.ensure_compiled(h) do
        {:module, _} ->
          for c <- h.commands_or_events() do
            :persistent_term.put(c, h)
          end

        {:error, _} ->
          :ok
      end
    end
  end

  @doc """
  Retrieves the handler module for a command or event.

  Searches the configured handlers for one that handles the given command or event module. Returns nil if no handler is registered.
  """
  @spec get(module()) :: module() | nil
  def get(command_or_event), do: :persistent_term.get(command_or_event, nil)
end
