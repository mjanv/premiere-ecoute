defmodule PremiereEcoute do
  @moduledoc false

  alias PremiereEcoute.Core

  defdelegate apply(command), to: Core
end
