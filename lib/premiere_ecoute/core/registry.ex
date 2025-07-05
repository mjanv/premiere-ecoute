defmodule PremiereEcoute.Core.Registry do
  @moduledoc false

  require Logger

  @table __MODULE__

  def register(command_or_event, handler) do
    Logger.debug("Register #{inspect(command_or_event)} to #{inspect(handler)}")
    :persistent_term.put({@table, command_or_event}, handler)
  end

  def get(command_or_event), do: :persistent_term.get({@table, command_or_event}, nil)
end
