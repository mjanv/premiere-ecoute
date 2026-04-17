---
name: event-store
description: How to define events, store them, retrieve them, and handle them via EventBus.
---

# Event Store

## Define an event

```elixir
defmodule PremiereEcoute.MyContext.Events.ThingHappened do
  use PremiereEcouteCore.Event, fields: [:thing_id, :user_id, :payload]
  # Generates: struct with :id + custom fields, Jason.Encoder, String.Chars
end
```

## Append events

```elixir
alias PremiereEcoute.Events.Store

# Simple append
Store.append(%ThingHappened{thing_id: 1, user_id: 2}, stream: "things", metadata: %{})
# Writes to "things-<event_id>" and links it in the "things" aggregate stream

# Conditional helpers — great for piping command results
result
|> Store.ok("things", fn thing -> %ThingHappened{thing_id: thing.id} end)   # only on {:ok, _}
|> Store.error("things", fn cs -> %ThingFailed{reason: cs} end)             # only on {:error, _}
|> Store.any("things", fn data -> %AnythingHappened{data: data} end)        # always
# Each helper returns the original result unchanged — safe to chain.
```

## Read events

```elixir
Store.read("things", :event)          # all events as structs, forward order; [] if stream missing
Store.read("things", :raw)            # all events as RecordedEvent structs
Store.last("things")                  # last 1 event (returns single struct or nil)
Store.last("things", 5)               # last 5 events (returns list)
Store.paginate("things", page: 1, size: 10)
```

Stream ID convention: `"<entity_plural>-<id>"` for per-entity stream, `"<entity_plural>"` for the aggregate link stream.

## Handle events

```elixir
defmodule PremiereEcoute.MyContext.EventHandler do
  use PremiereEcouteCore.EventBus.Handler

  event(PremiereEcoute.MyContext.Events.ThingHappened)  # registers this handler for this event

  @impl true
  def dispatch(%ThingHappened{thing_id: id}) do
    # broadcast PubSub, schedule Oban workers, etc.
    :ok
  end

  def dispatch(_), do: :ok
end
```

Register in `config/config.exs`:

```elixir
config :premiere_ecoute, :handlers, [
  PremiereEcoute.MyContext.EventHandler,
  # ...
]
```

Dispatch an event (typically from a command handler):

```elixir
PremiereEcouteCore.EventBus.dispatch(%ThingHappened{thing_id: 1})
PremiereEcouteCore.EventBus.dispatch([%ThingHappened{}, %AnotherEvent{}])
```

The bus looks up the handler via `Registry` (persistent term) and calls `dispatch/1`.
