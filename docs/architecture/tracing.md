# 🔭 Distributed tracing — first use case

> **Status:** implemented. This document is the design of record for the first trace; it was written
> before the code and updated to match what was built.
>
> **Scope:** exactly one trace, end to end. Everything else is explicitly a non-goal (§10).

## 1. Why trace at all

We are not short of telemetry. PromEx feeds Prometheus and Grafana with BEAM, Phoenix, Ecto and Oban
metrics, `PremiereEcoute.Telemetry.ApiMetrics` counts webhook events, and Sentry catches the
exceptions. What none of them can answer is *where the time went inside one unit of work*, because
the unit of work is spread across four BEAM processes and no single measurement spans them.

A metric says "vote processing p99 doubled last Friday". A trace says "it doubled because
`Report.generate/1` reloads every vote in the session on every batch of five, and Friday's session
had 4 000 votes". That second sentence is the one we cannot currently produce, and it is the whole
reason to introduce tracing.

## 2. The use case: a Twitch chat vote

**A `channel.chat.message` EventSub notification arriving at `POST /webhooks/twitch`, becoming a
persisted `Vote`, and ending as a `:session_summary` broadcast on the session's PubSub topic.**

This is the product's core loop — "vote and react, track and rate" is the feature the README leads
with — and it was chosen over the alternatives against four criteria:

| Criterion | Why the vote flow satisfies it |
|---|---|
| **It matters** | Every vote in every live session goes through it. Latency here is visible to the streamer's audience in the overlay. |
| **It is genuinely distributed** | It crosses three process boundaries inside the BEAM. A trace is the only tool that follows it; a histogram is not. |
| **It has unexplained latency** | The batch handler does a bulk insert *and* a full session report regeneration before broadcasting (§9). |
| **It is small** | One controller clause, one publish function, one pipeline. We can instrument it without switching on app-wide auto-instrumentation. |

### Alternatives considered

- **Spotify playback / album lookup** (`PremiereEcoute.Apis`) — real latency, but it happens inside
  a single process making an HTTP call. `ApiMetrics` and the circuit breaker already cover it, and a
  span would restate what a histogram already says.
- **Oban workers** (discography sync, notifications) — genuinely multi-process, but they are started
  by a cron tick, so there is no inbound request to root a trace in, and Oban Web already shows
  per-job timing.
- **Session start → Twitch poll creation** — crosses the command/event bus, but it fires a handful of
  times per session. Low volume means low diagnostic value per unit of instrumentation effort.

## 3. The path as it exists today

```
POST /webhooks/twitch
  └─ PremiereEcouteWeb.Webhooks.TwitchController.handle/2        twitch_controller.ex:30
       HMAC validation, ApiMetrics.webhook_event(:twitch, type)
       parses the payload into %MessageSent{}                     twitch_controller.ex:94
       └─ Sessions.publish_message(event)                         twitch_controller.ex:53
            └─ PremiereEcouteCore.publish(Scores.MessagePipeline, event)   sessions.ex:41
            └─ PremiereEcouteCore.publish(CollectionSession.MessagePipeline, event)
            └─ PremiereEcouteCore.publish(HashtagPipeline, event)
                 └─ BroadwayProducer.publish/2                    broadway_producer.ex:49
                      GenStage.cast(producer, %Message{...})   ← ⚠ process boundary
       responds 202
```

and then, asynchronously, in the pipeline (`sessions/scores/message_pipeline.ex`):

```
BroadwayProducer (GenStage producer process, concurrency: 1)
  └─ handle_message(:session, msg, _)                            message_pipeline.ex:46
       process/1: Cache.get(:sessions, broadcaster_id),
                  Vote.from_message(message, vote_options)        message_pipeline.ex:59
       put_batch_key(session_id) |> put_batcher(:writer)
       └─ handle_batch(:writer, messages, ...)   batch_size: 5    message_pipeline.ex:86
            Vote.create_all(...)                                  message_pipeline.ex:87
            Report.generate(%ListeningSession{id: session_id})    message_pipeline.ex:89
            PremiereEcoute.PubSub.broadcast("session:#{id}", ...) message_pipeline.ex:95
```

Producer, processor and batcher are three distinct long-lived processes, all distinct from the
Bandit request process. Four processes, one logical unit of work.

## 4. Where the trace breaks

There is exactly one seam, and it is a good one:

```elixir
# lib/premiere_ecoute_core/broadway_producer.ex:49
def publish(pipeline, event) do
  producer = Enum.random(Broadway.producer_names(pipeline))
  GenStage.cast(producer, %Message{acknowledger: NoopAcknowledger.init(), data: event})
end
```

`GenStage.cast/2` is a plain message send. OpenTelemetry context lives in the *sending* process's
process dictionary and does not travel with the message. Without an explicit hand-off, every span
created in the pipeline is an orphan root — the exact failure mode called out in the checklist.

The happy accident is that this is the *only* seam. Fixing it here fixes propagation for every
Broadway pipeline in the application at once — `Scores.MessagePipeline`, `Scores.PollPipeline`,
`Chat.HashtagPipeline`, `CollectionSession.MessagePipeline` — which makes the second and third
tracing use cases nearly free.

## 5. Target span tree

```
trace A ─ twitch.chat_message                      (Bandit request process, SERVER)
          └─ vote.process                          (Broadway processor process, INTERNAL)

trace B ─ vote.batch_write                         (Broadway batcher process, INTERNAL, root)
          │   ↖ link → trace A / vote.process
          │   ↖ link → trace A′ / vote.process
          │   ↖ link → … (one per message in the batch)
          ├─ vote.insert_all
          ├─ report.generate
          └─ session_summary.broadcast
```

Two traces, joined by links. §6.5 explains why that is the honest modelling and not a compromise.

## 6. Design

### 6.1 Dependencies

Deliberately minimal — the API, the SDK and one exporter:

```elixir
{:opentelemetry_api, "~> 1.5"},      # Tracer/Ctx macros, used from application code
{:opentelemetry, "~> 1.7"},          # SDK: sampler, span processor
{:opentelemetry_exporter, "~> 1.10"} # OTLP over http/protobuf
```

**No auto-instrumentation.** `opentelemetry_phoenix`, `opentelemetry_bandit` and
`opentelemetry_ecto` were tried and removed: each of them attaches globally, so they instrument
every HTTP request and every database query in the application, which is a much larger change than
"trace the vote flow". Only the selected path is traced, which means every span in this system was
put there on purpose. The cost is that the trace has no HTTP-level root and no per-query detail —
`twitch.chat_message` is the root, and the two database calls that matter are wrapped by hand
(§6.6).

Reconsider these once the first trace has proved its worth and there is an appetite for spans across
the whole application. That is a separate decision, and it should be taken deliberately rather than
inherited from this change.

`opentelemetry_process_propagator` also went with them. It resolves context through the process
*ancestry* (`$ancestors`), which covers `Task` and `spawn`, but not a message sent to a long-lived
process unrelated to the sender — so it would not have solved the Broadway boundary anyway (§6.3).

`open_telemetry_decorator` was left out too: the `@decorate` syntax buys little for six hand-written
spans and pulls a macro layer into modules that are otherwise plain.

Note that `PremiereEcouteCore` declares `use Boundary, deps: []`. Boundary only governs in-app
modules, so depending on `:opentelemetry_api` from core is fine. There is no setup step and nothing
to attach at boot — the SDK starts as an ordinary application dependency, and spans exist only where
the code creates them.

### 6.2 `PremiereEcouteCore.Tracing`

`lib/premiere_ecoute_core/tracing.ex`, added to the `exports` list in `lib/premiere_ecoute_core.ex`.
It is small on purpose — it exists to make the two things that are easy to get wrong (detaching, and
linking) hard to get wrong, not to wrap the OTel API.

```elixir
defmodule PremiereEcouteCore.Tracing do
  @moduledoc "OpenTelemetry helpers for carrying trace context across process boundaries."

  # Capture in the sending process.
  @spec context() :: OpenTelemetry.Ctx.t()
  def context()

  # Attach in the receiving process, run, and *always* detach.
  @spec with_context(OpenTelemetry.Ctx.t() | nil, (-> result)) :: result when result: var
  def with_context(ctx, fun)

  # Build span links from a list of captured contexts (fan-in).
  @spec links([OpenTelemetry.Ctx.t()]) :: [OpenTelemetry.link()]
  def links(contexts)

  # Thin sugar over OpenTelemetry.Tracer.with_span/3.
  defmacro span(name, do: block)
  defmacro span(name, opts, do: block)   # opts :: [attributes: map, links: list]
end
```

Everything it needs is in `opentelemetry_api` 1.5: `OpenTelemetry.Ctx.get_current/0`, `attach/1`,
`detach/1`; `OpenTelemetry.Tracer.current_span_ctx/1`; `OpenTelemetry.link/1` and
`OpenTelemetry.links/1`; and `links` is an accepted key in span start options.

### 6.3 Crossing the producer boundary

`Broadway.Message` (broadway 1.3.0) carries a `metadata: %{}` field that we are not using. That is
the vehicle:

```elixir
# lib/premiere_ecoute_core/broadway_producer.ex — sketch
def publish(pipeline, event) do
  producer = Enum.random(Broadway.producer_names(pipeline))
  message = %Message{
    acknowledger: NoopAcknowledger.init(),
    data: event,
    metadata: %{otel_ctx: Tracing.context()}
  }

  GenStage.cast(producer, message)
end
```

Two properties make this safe to put in shared core infrastructure:

- `publish/2` always runs in the process that owns the context, so the capture is always correct.
- When no span is active, `Ctx.get_current/0` returns an empty context and every consumer treats it
  as "no parent". Pipelines that are not instrumented — the hashtag and collection pipelines — are
  unaffected.

`Message.put_data/2` and `Message.failed/2` both preserve `metadata`, so the context survives from
`handle_message/3` through to `handle_batch/4` even though the message's `data` is replaced with the
vote map along the way.

### 6.4 Attach, and *detach*

Broadway processors are long-lived and handle message after message in the same process. Attaching a
context without detaching it leaks the trace into the next message, which produces traces that look
plausible and are wrong — the worst kind of instrumentation bug.

`with_context/2` therefore owns the whole lifecycle and is the only sanctioned way to attach:

```elixir
def with_context(nil, fun), do: fun.()

def with_context(ctx, fun) do
  token = OpenTelemetry.Ctx.attach(ctx)
  try do
    fun.()
  after
    OpenTelemetry.Ctx.detach(token)
  end
end
```

The `after` clause matters: `handle_message/3` can raise, and Broadway will happily hand the same
process the next message.

### 6.5 The batcher is a fan-in — links, not parenthood

`handle_batch/4` receives up to five messages that came from five unrelated HTTP requests and five
unrelated traces. There is no correct single parent for the resulting span.

The design is therefore: **`vote.batch_write` starts a new trace and carries one link per message
back to that message's `vote.process` span.**

```elixir
# lib/premiere_ecoute/sessions/scores/message_pipeline.ex — sketch
def handle_batch(:writer, messages, %BatchInfo{batch_key: session_id}, _context) do
  links =
    messages
    |> Enum.flat_map(fn
      %Message{metadata: %{otel_ctx: ctx}} -> [ctx]
      _ -> []
    end)
    |> Tracing.links()

  Tracing.span "vote.batch_write",
    links: links,
    attributes: %{"session.id" => session_id, "batch.size" => length(messages)} do
    # … existing body, with vote.insert_all / report.generate / broadcast spans inside
  end
end
```

This falls out naturally rather than needing to be forced: we only ever attach context inside
`handle_message/3`, and `with_context/2` detaches it again, so the batcher process has no ambient
context and the span becomes a root.

**Alternative rejected:** parent the batch span on the first message's context and link the rest.
It is less code and keeps one trace visually intact, but it attributes the entire batch's database
time to whichever vote happened to be first in the queue. The point of the exercise is to find out
where time goes; a modelling choice that misattributes time defeats it. This also matches the
OpenTelemetry messaging conventions, which specify a root span with links for batch receive
operations.

**Accepted cost:** in Tempo, the request trace ends at `vote.process`, and the database work lives
one click away in the linked batch trace. Tempo renders span links as navigable, so this is a click,
not a dead end — but it is a real ergonomic cost and worth confirming we are happy with it before
building.

### 6.6 Span inventory

| Span | Process | Parent | Attributes |
|---|---|---|---|
| `twitch.chat_message` | Bandit request | root, `kind: :server` | `twitch.broadcaster_id`, `twitch.user_id`, `chat.message.length`, `twitch.is_streamer` |
| `vote.process` | Broadway processor | `twitch.chat_message` via message metadata | `session.id`, `track.id`, `vote.value`, `vote.outcome` (`:ok` / `:no_active_track` / `:unparseable`) |
| `vote.batch_write` | Broadway batcher | root + N links | `session.id`, `batch.size` |
| `vote.insert_all` | Broadway batcher | `vote.batch_write` | `db.rows` |
| `report.generate` | Broadway batcher | `vote.batch_write` | `session.id`, `report.track_count` |
| `session_summary.broadcast` | Broadway batcher | `vote.batch_write` | `pubsub.topic` |

The root span wraps only the `%MessageSent{}` branch of the controller's `case` — poll events, stream
online/offline and reward redemptions are untouched by this change.

**Privacy.** Chat message *text* is never recorded as a span attribute; only its length. Twitch
broadcaster and user ids are pseudonymous identifiers we already persist (`votes.viewer_id`) and log,
so recording them adds no new category of data — but spans go to a third party in production, so
this belongs in the privacy review before rollout, and the retention window on the tracing backend
should be set deliberately rather than left at its default.

## 7. Configuration

| Environment | Exporter | Sampler | Rationale |
|---|---|---|---|
| `:dev` | OTLP http/protobuf → `http://localhost:4318` | always on | Local Tempo, low volume, you want every trace you generate. |
| `:test` | `:none` | — | No exporter, no background flushing, no interference with the async test suite. |
| `:prod` | OTLP → `OTEL_EXPORTER_OTLP_ENDPOINT` | always on (**100 %**) | See the note below. |

```elixir
# config/config.exs
config :opentelemetry,
  resource: [service: [name: "premiere_ecoute", version: Mix.Project.config()[:version]]],
  span_processor: :batch,
  traces_exporter: :otlp,
  sampler: :always_on

# config/dev.exs
config :opentelemetry_exporter, otlp_protocol: :http_protobuf, otlp_endpoint: "http://localhost:4318"

# config/test.exs
config :opentelemetry, traces_exporter: :none
```

**Sampling is at 100 % for now, deliberately.** The original design proposed a 10 % ratio in
production, on the grounds that chat is high volume during a live session. That was reversed for the
first rollout: while we are still learning what these traces say, a sampled-out trace is one we
cannot go back and ask about, and the flow is narrow enough — one webhook branch, one pipeline — that
its volume is bounded by chat activity rather than by total traffic. This is the first knob to turn
if span volume or cost becomes a problem; swapping `sampler: :always_on` for
`{:parent_based, %{root: {:trace_id_ratio_based, 0.1}}}` needs no code change. With no
auto-instrumentation attached, 100 % here means every *vote*, not every request and every query —
the volume is bounded by chat activity on the one branch that is instrumented.

Production values are read in `config/runtime.exs` through Dotenvy `env!/3`, consistent with the rest
of the project's configuration, rather than relying on the `OTEL_*` variables the Erlang SDK reads
directly — so that a missing endpoint disables export cleanly instead of failing at boot.

Because the sampling decision is taken when the root span starts in the controller and then rides
along in the propagated context, a trace that is sampled out produces no pipeline spans either. The
sampler is the single knob for the whole feature.

## 8. Backend

Local: a `tempo` service added to `docker-compose.yml` (OTLP http on `4318`, query API on `3200`)
with a minimal `priv/tempo/tempo.yaml`, plus a Tempo datasource in
`priv/grafana/provisioning/datasources/`. Grafana is already provisioned and login-free locally, so
traces show up next to the existing PromEx dashboards with no extra setup for a developer running
`docker compose up -d`.

Production: point `OTEL_EXPORTER_OTLP_ENDPOINT` at Grafana Cloud Tempo, with credentials in
`OTEL_EXPORTER_OTLP_HEADERS`. This is the same Grafana org that already receives PromEx dashboards
via `GRAFANA_HOST` / `GRAFANA_API_TOKEN`, so it adds an endpoint but not a vendor.

Log correlation via a Loki derived field on `trace_id` is listed as a follow-up (§10) — worth doing,
but it is a second deliverable and should not gate the first trace.

## 9. What we expect the first trace to show

A concrete, falsifiable hypothesis, so that we can tell afterwards whether this was worth doing:

`handle_batch/4` calls `Report.generate/1` on **every** batch of five votes, and
`Report.generate/1` (`sessions/retrospective/report.ex:97`) loads *all* votes and *all* polls for the
session, recomputes every track summary, then upserts and preloads the report:

```elixir
votes = Vote.all(where: [session_id: session_id])
polls = Poll.all(where: [session_id: session_id])
track_summaries = calculate_track_summaries(session, votes, polls, mode)
```

That is O(votes in session) work per batch, which over the life of a session is quadratic in the
number of votes. We expect `report.generate` to dominate `vote.batch_write`, and the gap between it
and `vote.insert_all` to widen as a session accumulates votes.

If the trace confirms it, the fix — incremental summary updates, or debouncing report regeneration —
is a separate piece of work that this trace will have justified and will then measure. If the trace
refutes it, we have learned something cheaply and the instrumentation stays useful anyway.

## 10. Non-goals

Explicitly **not** in this change, to keep the first trace reviewable:

- App-wide Phoenix / Bandit / Ecto auto-instrumentation (§6.1).
- Tracing the other three Broadway pipelines, the command and event buses, or Oban jobs. The
  producer-boundary fix (§6.3) makes these cheap later; that is the point, but it is not this change.
- Trace-to-log correlation (`trace_id` in Logger metadata, Loki derived fields).
- Tail-based sampling via a collector, and "always keep errors".
- Replacing anything PromEx currently does. Metrics and traces answer different questions and both
  stay.

## 11. Risks

| Risk | Mitigation |
|---|---|
| Context leaks between messages in a long-lived Broadway processor | `with_context/2` is the only attach path and detaches in an `after` block (§6.4). |
| Exporter unavailable or slow in production | Batch span processor drops on a full queue rather than blocking the caller; export failure must never affect vote processing. Verify by running with a black-holed endpoint. |
| Span volume / cost during a busy live session | Accepted for now at 100 % sampling, on the understanding that this is the first thing to turn down. `sampler` is a one-line config change. |
| Tracing overhead on the hot vote path | Six spans per vote batch, no synchronous I/O on the request path. Confirm against the existing PromEx vote-processing metrics before and after. |
| The test suite becomes flaky or slower | `traces_exporter: :none` in `:test`; no SDK background work. |
| Chat content leaking into a third-party backend | Message text is never an attribute (§6.6); privacy review before production rollout. |

## 12. Verification plan

1. `mix quality` and the full test suite pass — instrumentation must be invisible to existing tests.
   The new coverage lives in `test/premiere_ecoute_core/tracing_test.exs` and
   `test/premiere_ecoute/sessions/scores/message_pipeline_tracing_test.exs`, on top of the
   `PremiereEcoute.TracingCase` helper, which swaps in a synchronous processor that forwards every
   finished span to the test process.
2. `docker compose up -d`, run a local session, post a chat vote through the mock Twitch server, and
   confirm in Grafana that **one** trace is rooted at `twitch.chat_message` and contains
   `vote.process`, created in a different process.
   Confirm too that browsing the app produces **no** other traces — nothing outside this path is
   instrumented.
3. Confirm the linked `vote.batch_write` trace is reachable from it, and that its link count equals
   the batch size.
4. Send 20 votes and confirm there are 20 distinct traces, not one — i.e. that context is not
   leaking between messages.
5. Compare vote-processing latency in the existing PromEx dashboard before and after.
6. Watch span volume and exporter latency for one full live session before deciding whether 100 %
   sampling stays.

## 13. Open questions

- Is the two-trace split (§6.5) acceptable ergonomically, or would a single trace parented on the
  first message be preferred despite misattributing batch time?
- The hand-wrapped `report.generate` span shows how long the report takes but not which of its
  queries is responsible. Is that enough to act on, or is `opentelemetry_ecto` — and the app-wide
  query spans that come with it — worth revisiting later?
- ~~Is 10 % the right starting sample rate?~~ Settled for now: 100 %, see §7. The follow-up question
  stands — a per-broadcaster or per-session sampling rule may serve us better than any uniform ratio,
  since the unit we usually want to debug is one streamer's session.
- Grafana Cloud Tempo, or self-hosted Tempo alongside the existing stack?
