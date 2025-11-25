defmodule PremiereEcouteCore.Aggregate.Entity do
  @moduledoc """
  Base module for aggregate entities.
  """

  defmacro __using__(opts) do
    quote do
      use PremiereEcouteCore.Aggregate, unquote(opts)
    end
  end
end
