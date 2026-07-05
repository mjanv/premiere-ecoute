---
name: code-architecture
description: Code architecture guidelines for this codebase — PremiereEcouteCore patterns (Aggregate, Event Store, and more). Use when defining schemas, events, or wiring event/command handlers.
---

# Code architecture

Reference guide for `PremiereEcouteCore` architectural patterns used throughout this codebase.
Each pattern has its own file under `references/`. Read the one relevant to the current task.

## Patterns

- [Aggregate](references/aggregate.md) — Ecto schemas with generated CRUD
- [Event Store](references/event-store.md) — event definition, append/read, EventBus handlers

To document a new pattern (e.g. command bus, context macros), add a new file under `references/`
and list it here — don't create a separate skill for it.
