defmodule PremiereEcoute.Core.Entity do
  @moduledoc false

  defmacro __using__(opts) do
    quote do
      use PremiereEcoute.Core.Aggregate, unquote(opts)
    end
  end
end
