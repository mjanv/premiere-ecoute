defmodule PremiereEcouteCore.Context do
  @moduledoc """
  Makes a context module runtime-swappable and mockable in tests.

  The context module acts as its own behaviour: declare `@callback` on it to define the mockable
  surface. `test_helper.exs` picks it up automatically and generates a `__MODULE__.Mock` via Mox.
  In tests, call `ctx.mock(context)` in setup to swap the implementation for the duration of the test.

      defmodule MyApp.Sessions do
        use PremiereEcouteCore.Context

        @callback publish_message(map()) :: :ok
      end

      # In test_helper.exs — already wired up, no changes needed
      Mox.defmock(Sessions.Mock, for: Sessions.behaviours())

      # In a test
      setup_mock(PremiereEcoute.Sessions)

      test "publishes a message" do
        expect(Sessions.Mock, :publish_message, fn _ -> :ok end)
        ...
      end
  """

  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(opts) do
    name = Keyword.get(opts, :name, nil)

    quote do
      @app :premiere_ecoute
      @name unquote(name) || __MODULE__ |> Module.split() |> List.last() |> String.downcase() |> String.to_atom()

      def name, do: @name
      def impl, do: Application.get_env(@app, @name, __MODULE__)
      def behaviours, do: __MODULE__

      if Mix.env() == :test do
        def mock(_context) do
          api = Application.fetch_env(@app, @name)
          Application.put_env(@app, @name, Module.concat([__MODULE__, Mock]))

          ExUnit.Callbacks.on_exit(fn ->
            case api do
              {:ok, value} -> Application.put_env(@app, @name, value)
              :error -> Application.delete_env(@app, @name)
            end
          end)
        end
      end
    end
  end
end
