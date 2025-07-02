defmodule PremiereEcoute.Core.CommandBus.Registry do
  @moduledoc false

  @table :command_bus_registry

  def register(command, handler), do: :persistent_term.put({@table, command}, handler)
  def get(command), do: :persistent_term.get({@table, command}, nil)
end
