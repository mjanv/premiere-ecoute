defmodule PremiereEcouteCore.Context.Helpers do
  @moduledoc false

  @doc """
  Convenience macro for setting up a context mock in tests.

      setup_mock(PremiereEcoute.Sessions)

  Equivalent to:

      setup {PremiereEcoute.Sessions, :mock}
  """
  defmacro setup_mock(context_module) do
    quote do
      setup {unquote(context_module), :mock}
    end
  end
end
