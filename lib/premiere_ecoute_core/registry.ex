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

  @handlers Application.compile_env(:premiere_ecoute, :handlers, [])

  def get(command_or_event) do
    Enum.find(@handlers, fn h ->
      {status, _} = Code.ensure_compiled(h)
      status == :module && command_or_event in h.commands_or_events()
    end)
  end
end
