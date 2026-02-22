defmodule PremiereEcouteCore.Supervisor do
  @moduledoc false

  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(opts) do
    children = Keyword.get(opts, :children, [])
    mandatory = Keyword.get(opts, :mandatory, [])
    optionals = Keyword.get(opts, :optionals, [])

    quote do
      use Supervisor

      @spec start_link(keyword()) :: Supervisor.on_start()
      def start_link(args) do
        Supervisor.start_link(__MODULE__, args, name: __MODULE__)
      end

      @impl true
      def init(_args) do
        optionals =
          case Application.get_env(:premiere_ecoute, :environment) do
            :test -> []
            _ -> unquote(optionals)
          end

        Supervisor.init(unquote(children) ++ unquote(mandatory) ++ optionals, strategy: :one_for_one)
      end
    end
  end
end
