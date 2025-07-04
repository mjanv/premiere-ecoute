defmodule PremiereEcoute.Core do
  @moduledoc false

  alias PremiereEcoute.Core.CommandBus
  alias PremiereEcoute.Core.EventBus

  defdelegate apply(command), to: CommandBus
  defdelegate dispatch(command), to: EventBus
end
