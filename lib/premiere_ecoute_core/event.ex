defmodule PremiereEcouteCore.Event do
  @moduledoc """
  Base module for domain events.

  Provides struct definition, JSON encoding, and string representation for event sourcing. Events are automatically configured with an ID field and custom fields specified in options.
  """

  @doc """
  Extracts event name from event struct.

  Returns last segment of module name as event identifier.
  """
  @spec name(struct()) :: String.t()
  def name(event), do: event.__struct__ |> Module.split() |> List.last()

  @doc """
  Injects event functionality into using module.

  Generates struct with ID and custom fields, plus Jason encoder and String.Chars protocol implementations.
  """
  defmacro __using__(opts) do
    fields = Keyword.get(opts, :fields, [])

    quote do
      defstruct [:id] ++ unquote(fields)

      defimpl Jason.Encoder, for: __MODULE__ do
        def encode(event, opts) do
          Jason.Encode.map(Map.take(event, unquote(fields)), opts)
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
