defmodule PremiereEcoute.Core.EventBus.Handler do
  @moduledoc false

  defmacro __using__(opts) do
    events =
      opts
      |> Keyword.get(:events, [])
      |> Enum.map(fn {_, _, event} -> Module.concat(event) end)

    quote location: :keep do
      @behaviour PremiereEcoute.Core.EventBus.Handler

      for event <- unquote(events) do
        PremiereEcoute.Core.Registry.register(event, __MODULE__)
      end

      def dispatch(_event), do: :ok

      defoverridable dispatch: 1
    end
  end

  @callback dispatch(struct()) :: :ok | {:error, any()}
end
