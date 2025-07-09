defmodule PremiereEcoute.Core.Registry do
  @moduledoc false

  require Logger

  @handlers Application.compile_env(:premiere_ecoute, :handlers, [])

  def get(command_or_event) do
    Enum.find(@handlers, fn h -> Code.ensure_compiled(h) && command_or_event in h.commands_or_events() end)
  end
end
