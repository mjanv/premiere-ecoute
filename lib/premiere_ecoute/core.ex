defmodule PremiereEcoute.Core do
  @moduledoc """
  Core system facade module

  Provides centralized access to the application's command and event processing systems. This module acts as the primary interface for executing commands through the command bus and dispatching events through the event bus.
  """

  alias PremiereEcoute.Core.CommandBus
  alias PremiereEcoute.Core.EventBus

  defdelegate apply(command), to: CommandBus
  defdelegate dispatch(command), to: EventBus
end
