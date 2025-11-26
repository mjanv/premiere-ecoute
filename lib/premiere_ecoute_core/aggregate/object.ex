defmodule PremiereEcouteCore.Aggregate.Object do
  @moduledoc """
  Base module for aggregate objects.
  """

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      import Ecto.Changeset
    end
  end
end
