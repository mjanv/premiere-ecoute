defmodule PremiereEcoute.Core do
  @moduledoc false

  alias PremiereEcoute.Core.CommandBus

  defdelegate apply(command), to: CommandBus
end
