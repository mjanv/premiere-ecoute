defmodule PremiereEcouteCore.Event do
  @moduledoc false

  def name(event), do: event.__struct__ |> Module.split() |> List.last()

  defmacro __using__(opts) do
    fields = Keyword.get(opts, :fields, [])

    quote do
      defstruct [:id] ++ unquote(fields)

      defimpl Jason.Encoder, for: __MODULE__ do
        def encode(event, opts) do
          event
          |> Map.take(unquote(fields))
          |> Jason.Encode.map(opts)
        end
      end

      defimpl String.Chars, for: __MODULE__ do
        def to_string(event) do
          "#{inspect(event)}"
        end
      end
    end
  end
end

defimpl Jason.Encoder, for: EventStore.RecordedEvent do
  def encode(
        %{event_id: event_id, event_type: "Elixir.PremiereEcoute.Events." <> event_type, data: data, created_at: created_at},
        opts
      ) do
    Jason.Encode.map(%{event_id: event_id, event_type: event_type, details: data, timestamp: created_at}, opts)
  end
end
