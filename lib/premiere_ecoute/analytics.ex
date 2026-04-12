defmodule PremiereEcoute.Analytics do
  @moduledoc """
  Analytics context.

  Two flavours of time-based aggregation:

    * `Events` — queries over the event store (`event_store.events`). Use for data tracked via event sourcing.
    * `Aggregates` — queries over any Ecto schema table via `inserted_at`. Usefor data not tracked via event sourcing.
  """

  alias PremiereEcoute.Analytics.Aggregates
  alias PremiereEcoute.Analytics.Events

  defdelegate aggregate_events(event_module, unit, opts \\ []), to: Events, as: :aggregate
  defdelegate aggregate_schema(schema, unit, opts \\ []), to: Aggregates, as: :aggregate
end
