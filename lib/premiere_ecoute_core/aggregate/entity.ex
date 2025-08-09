defmodule PremiereEcouteCore.Aggregate.Entity do
  @moduledoc false

  defmacro __using__(opts) do
    quote do
      use PremiereEcouteCore.Aggregate, unquote(opts)
    end
  end
end
