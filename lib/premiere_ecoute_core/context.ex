defmodule PremiereEcouteCore.Context do
  @moduledoc false

  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(opts) do
    name = Keyword.get(opts, :name, [])

    quote do
      use Ecto.Schema

      def behaviours, do: __MODULE__
      def impl, do: Application.get_env(:premiere_ecoute, unquote(name), __MODULE__)

      def mock(_context) do
        api = Application.fetch_env(:premiere_ecoute, unquote(name))
        Application.put_env(:premiere_ecoute, unquote(name), Module.concat([__MODULE__, Mock]))

        ExUnit.Callbacks.on_exit(fn ->
          case api do
            {:ok, value} -> Application.put_env(:premiere_ecoute, unquote(name), value)
            :error -> Application.delete_env(:premiere_ecoute, unquote(name))
          end
        end)
      end
    end
  end
end
