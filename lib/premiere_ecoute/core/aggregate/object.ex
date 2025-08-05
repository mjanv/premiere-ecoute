defmodule PremiereEcoute.Core.Aggregate.Object do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      import Ecto.Changeset
    end
  end
end
