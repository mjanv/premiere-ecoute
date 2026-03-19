# Playlist Automations — Design Plan

## Overview

Playlist automations let streamers define sequences of playlist operations (steps) that run immediately, at a scheduled datetime, or on a recurring cron schedule. Steps execute sequentially and share a pipeline context. A step failure stops the run and notifies the user in-app.

---

## Data Model

### `playlist_automations` — Automation definitions, including steps

| Column | Type | Notes |
|---|---|---|
| `id` | `bigserial` | PK |
| `user_id` | `uuid` | FK → `users`, NOT NULL |
| `name` | `varchar` | NOT NULL |
| `description` | `text` | nullable |
| `enabled` | `boolean` | default `true` |
| `schedule_type` | `enum(manual, once, recurring)` | NOT NULL |
| `cron_expression` | `varchar` | nullable — standard 5-field cron, used for `recurring` |
| `steps` | `jsonb` | Ordered array of step definitions (see shape below) |
| `inserted_at` | `timestamptz` | |
| `updated_at` | `timestamptz` | |

Index: `(user_id)`.

`next_run_at` and `last_run_at` are not stored — they are derived and exposed as virtual fields on the `Automation` schema:

```elixir
field :next_run_at, :utc_datetime, virtual: true
field :last_run_at, :utc_datetime, virtual: true
```

- **`next_run_at`**: `oban_jobs.scheduled_at WHERE worker = 'AutomationRunWorker' AND args->>'automation_id' = ? AND state = 'scheduled' ORDER BY scheduled_at ASC LIMIT 1`
- **`last_run_at`**: `automation_runs.inserted_at WHERE automation_id = ? ORDER BY inserted_at DESC LIMIT 1`

The `Automations` context populates these fields when loading automations for display. Raw DB reads (e.g. inside the worker) do not need them and skip the join.

Every `AutomationRunWorker` job carries `args: %{"automation_id" => id}` — that is the natural join key, no FK needed on the automation.

Each element of `steps` has this shape:

```json
{"position": 1, "action_type": "empty_playlist", "config": {"playlist_id": "lp_fresh_picks"}}
```

Steps have no independent IDs — they are identified by their `position` within the automation. `config` is validated against the action's `validate_config/1` when the automation is saved.

---

### `automation_runs` — Each execution instance, including per-step results

| Column | Type | Notes |
|---|---|---|
| `id` | `bigserial` | PK |
| `automation_id` | `bigint` | FK → `playlist_automations`, NOT NULL |
| `oban_job_id` | `bigint` | FK → `oban_jobs`, NOT NULL — the job that produced this run |
| `status` | `enum(running, completed, failed)` | |
| `trigger` | `enum(manual, scheduled)` | |
| `steps` | `jsonb` | Ordered array of step results (see shape below) |
| `started_at` | `timestamptz` | nullable |
| `finished_at` | `timestamptz` | nullable |
| `inserted_at` | `timestamptz` | |
| `updated_at` | `timestamptz` | |

Index: `(automation_id, inserted_at DESC)` for paginated history per automation.

Each element of `steps` has this shape:

```json
{
  "position": 1,
  "action_type": "empty_playlist",
  "status": "completed",
  "output": {"removed_count": 47},
  "error": null,
  "started_at": "2026-04-01T09:00:01Z",
  "finished_at": "2026-04-01T09:00:02Z"
}
```

`action_type` and `config` are snapshotted from the automation at the moment the run starts, so history remains readable after the automation's steps are edited.

---

### `user_notifications` — Persistent notification records

| Column | Type | Notes |
|---|---|---|
| `id` | `bigserial` | PK |
| `user_id` | `uuid` | FK → `users`, NOT NULL |
| `type` | `varchar` | Registered type key, e.g. `"automation_failure"` |
| `data` | `jsonb` | Context-specific payload; each type owns its own schema |
| `read_at` | `timestamptz` | nullable — `null` means unread; timestamp enables analytics |
| `inserted_at` | `timestamptz` | |

`read_at` over a `read boolean`: gives when the notification was seen, useful for "new since last visit" queries and future analytics.

Indexes: `(user_id, read_at, inserted_at DESC)` — the primary query pattern; `(user_id, inserted_at DESC)` — for listing all notifications regardless of read state.

---

## Action System

### `Action` behaviour

```elixir
defmodule PremiereEcoute.Automations.Action do
  @type config  :: map()
  @type context :: map()  # accumulated outputs from previous steps, keyed by step position
  @type output  :: map()

  @doc "Unique string key used in playlist_automations.steps[].action_type"
  @callback id() :: String.t()

  @doc "Validates action-specific config; returns errors for UI form display"
  @callback validate_config(config()) :: :ok | {:error, [String.t()]}

  @doc "Executes the action; receives static config, pipeline context, and user scope"
  @callback execute(config(), context(), PremiereEcoute.Accounts.Scope.t()) ::
              {:ok, output()} | {:error, term()}
end
```

### `ActionRegistry` — compile-time registry

```elixir
defmodule PremiereEcoute.Automations.ActionRegistry do
  @actions %{
    "empty_playlist"                 => PremiereEcoute.Automations.Actions.EmptyPlaylist,
    "add_tracks_from_playlist"       => PremiereEcoute.Automations.Actions.AddTracksFromPlaylist,
    "remove_duplicates"              => PremiereEcoute.Automations.Actions.RemoveDuplicates,
    "remove_tracks_by_release_date"  => PremiereEcoute.Automations.Actions.RemoveTracksByReleaseDate,
    "remove_tracks_by_added_date"    => PremiereEcoute.Automations.Actions.RemoveTracksByAddedDate,
  }

  def get(action_type), do: Map.fetch(@actions, action_type)
  def all(), do: @actions
end
```

New action types are added here. The registry is compile-time: no dynamic dispatch overhead, trivially `grep`-able.

### Initial actions catalogue

| `action_type` | Config fields | Description |
|---|---|---|
| `empty_playlist` | `playlist_id` | Remove all tracks from a playlist |
| `add_tracks_from_playlist` | `source_playlist_id`, `target_playlist_id` | Copy all tracks from source into target |
| `remove_duplicates` | `playlist_id` | Remove duplicate tracks (by ISRC, fall back to provider track ID) |
| `remove_tracks_by_release_date` | `playlist_id`, `older_than_days` | Remove tracks whose release date is older than N days |
| `remove_tracks_by_added_date` | `playlist_id`, `older_than_days` | Remove tracks added to the playlist more than N days ago |

---

## Pipeline Context

Each step receives two inputs:
- **`config`** — static map stored in `playlist_automations.steps[].config`, validated when the automation is saved
- **`context`** — flat map, the result of merging all previous steps' outputs in order

```elixir
# Step 1 output: %{removed_count: 47}
# Step 2 output: %{added_count: 47}
# context available to step 3: %{removed_count: 47, added_count: 47}
```

`config` is always static. Steps that need to reference a previous step's output read from `context` directly. There is no templating DSL in config — action logic handles cross-step references explicitly. If two steps emit the same key, the later step wins (last-write-wins merge).

---

## Execution Flow

```
Trigger (create/edit/enable automation, or manual "Run now")
  └── AutomationScheduling.schedule(automation, trigger)
        ├── Oban.insert(AutomationRunWorker.new(%{automation_id: id}))          manual
        ├── Oban.insert(AutomationRunWorker.at(%{automation_id: id}, at))  once — `at` provided by caller at creation time
        └── Oban.insert(AutomationRunWorker.at(%{automation_id: id}, next_run_at))   recurring

AutomationRunWorker.perform(%Job{id: job_id, args: %{"automation_id" => id}})
  │
  ├── 1. Load automation
  │
  ├── 2. Schedule next run FIRST (before touching anything else)
  │     :recurring → compute next_run_at from cron_expression
  │                  Oban.insert(AutomationRunWorker.at(%{automation_id}, next_run_at))
  │     :once      → update automation: enabled = false
  │     :manual    → nothing
  │
  ├── 3. Insert automation_run (status: :running, oban_job_id: job_id, started_at: now())
  │
  ├── 4. Build user Scope
  │
  ├── 5. Fold over automation.steps (snapshot), accumulating context = %{} and step_results = []:
  │
  │     For each step:
  │       ├── {:ok, module} = ActionRegistry.get(step["action_type"])
  │       ├── module.execute(step["config"], context, scope)
  │       │
  │       ├── {:ok, output} →
  │       │     Append %{position, action_type, status: :completed, output, ...} to step_results
  │       │     context = Map.merge(context, output)
  │       │     Continue
  │       │
  │       └── {:error, reason} →
  │             Append %{..., status: :failed, error: %{message: inspect(reason)}} to step_results
  │             Append %{..., status: :skipped} for each remaining step
  │             Update run: status: :failed, steps: step_results, finished_at: now()
  │             Notifications.dispatch(user, "automation_failure", %{...})
  │             return :ok  ← job succeeds; failure is a domain outcome, not a crash
  │
  └── 6. Update run: status: :completed, steps: step_results, finished_at: now()
```

**Step 2 runs before step 3**: the next occurrence is scheduled before the current run is even recorded. This ensures the recurring chain survives a failed or crashed run — the next job is already in Oban regardless of what happens to the current execution.

**Step results** are accumulated in memory and written in a single update on completion or failure. No intermediate DB writes per step.

**The Oban job always returns `:ok`**. Domain failures are recorded in `automation_runs`, not surfaced as job errors. Oban retries are reserved for infrastructure failures (process crash, DB down). This prevents phantom retries re-running destructive steps (e.g., emptying a playlist twice).

---

## Scheduling

Oban is the scheduler. There is no custom polling worker. The `AutomationScheduling` service wraps `Oban.insert` and `Oban.cancel_job` calls. Oban handles timing, persistence, and delivery.

### `AutomationScheduling` service

```elixir
defmodule PremiereEcoute.Automations.Services.AutomationScheduling do

  def schedule(%Automation{schedule_type: :manual} = automation) do
    AutomationRunWorker.now(%{automation_id: automation.id})
  end

  def schedule(%Automation{schedule_type: :once} = automation, at) do
    AutomationRunWorker.at(%{automation_id: automation.id}, at)
  end

  def schedule(%Automation{schedule_type: :recurring, cron_expression: expr} = automation) do
    AutomationRunWorker.at(%{automation_id: automation.id}, next_run_at(expr))
  end

  def cancel(%Automation{id: id}) do
    from(j in Oban.Job,
      where: j.worker == "PremiereEcoute.Automations.Workers.AutomationRunWorker",
      where: fragment("?->>'automation_id' = ?", j.args, ^to_string(id)),
      where: j.state in ["scheduled", "available", "retryable"]
    )
    |> Repo.all()
    |> Enum.each(&Oban.cancel_job(&1.id))
  end

  def next_run_at(cron_expression) do
    {:ok, expr} = Crontab.CronExpression.Parser.parse(cron_expression)
    Crontab.Scheduler.get_next_run_date!(expr, DateTime.utc_now())
  end
end
```

`cancel/1` cancels all non-executing planned jobs for an automation by querying `oban_jobs` on `args->>'automation_id'`. It is called before any operation that changes the schedule: edit, disable, delete. The caller re-schedules with the new parameters if appropriate.

### `HistoryPrunerWorker` — daily cleanup

```elixir
# config.exs:
{"0 3 * * *", PremiereEcoute.Automations.Workers.HistoryPrunerWorker}
```

Deletes `automation_runs` older than `@retention_days` (default: 30). Step results are embedded, so no cascade needed.

---

## Notification System

Automations are the first consumer, but the system is built as a standalone `Notifications` context usable by any part of the application. New notification types are added by registering a module — no changes to the core system are needed.

### Design principles

- **DB-first**: every notification is persisted before any delivery attempt. A streamer who is offline when an automation fails will see the notification on their next visit.
- **Channel-agnostic dispatch**: the `Dispatcher` routes to one or more delivery channels (in-app, email, Twitch chat…) based on the notification type's declared defaults and future per-user preferences. Each channel is independent.
- **Type registry**: notification types are modules implementing a behaviour. The type owns its `data` schema, rendering logic (title, body, icon, link), and default channels. Consuming contexts register their types; the core system doesn't need to know about them.
- **No title/body columns**: rendering is the type module's responsibility, not the DB's. The `data` jsonb is the source of truth; `title` and `body` are derived at display time. This avoids stale text in the DB when copy changes.

---

### `NotificationType` behaviour

```elixir
defmodule PremiereEcoute.Notifications.NotificationType do
  @type data :: map()

  @doc "Unique string key stored in user_notifications.type"
  @callback type() :: String.t()

  @doc "Default delivery channels for this notification type"
  @callback channels() :: [:in_app | :email | :twitch_chat]

  @doc "Derives display content from the stored data map"
  @callback render(data()) :: %{
    title: String.t(),
    body: String.t(),
    icon: String.t(),          # heroicon name or emoji fallback
    path: String.t() | nil     # link target; nil = no action
  }
end
```

### `NotificationRegistry` — compile-time registry

```elixir
defmodule PremiereEcoute.Notifications.NotificationRegistry do
  @types %{
    "automation_failure" => PremiereEcoute.Notifications.Types.AutomationFailure,
    # future:
    # "collection_session_completed" => PremiereEcoute.Notifications.Types.CollectionSessionCompleted,
    # "system_announcement"          => PremiereEcoute.Notifications.Types.SystemAnnouncement,
  }

  def get(type), do: Map.fetch(@types, type)
  def all(), do: @types
end
```

### Type implementation example

```elixir
defmodule PremiereEcoute.Notifications.Types.AutomationFailure do
  @behaviour PremiereEcoute.Notifications.NotificationType

  @impl true
  def type(), do: "automation_failure"

  @impl true
  def channels(), do: [:in_app]   # email added here when ready

  @impl true
  def render(%{"automation_name" => name, "run_id" => run_id, "automation_id" => auto_id}) do
    %{
      title: "Automation failed: #{name}",
      body: "One or more steps encountered an error and the run was stopped.",
      icon: "exclamation-circle",
      path: "/playlists/automations/#{auto_id}?run=#{run_id}"
    }
  end
end
```

The `data` map stores `automation_name` as a snapshot so the notification remains readable even if the automation is later renamed or deleted.

---

### `Dispatcher` — routes to channels

```elixir
defmodule PremiereEcoute.Notifications.Dispatcher do
  alias PremiereEcoute.Notifications.{NotificationRegistry, Notification}
  alias PremiereEcoute.Repo

  def dispatch(user, type, data) do
    with {:ok, type_module} <- NotificationRegistry.get(type),
         {:ok, notification} <- persist(user, type, data) do
      type_module.channels()
      |> Enum.each(&deliver(&1, user, notification, type_module))

      {:ok, notification}
    end
  end

  defp persist(user, type, data) do
    %Notification{}
    |> Notification.changeset(%{user_id: user.id, type: type, data: data})
    |> Repo.insert()
  end

  defp deliver(:in_app, user, notification, type_module) do
    rendered = type_module.render(notification.data)
    PremiereEcoute.PubSub.broadcast(
      "user:#{user.id}",
      {:notification, notification, rendered}
    )
  end

  defp deliver(:email, user, notification, type_module) do
    # delegate to Accounts.Mailer when implemented
    :ok
  end

  defp deliver(:twitch_chat, user, notification, _type_module) do
    # delegate to Apis.twitch() when implemented
    :ok
  end
end
```

---

### `Notifications` public context

```elixir
defmodule PremiereEcoute.Notifications do
  @doc "Main entry point for all contexts — persists and dispatches"
  def dispatch(user, type, data)

  @doc "Unread notifications for a user, ordered by recency"
  def list_unread(user)

  @doc "All notifications (read + unread), paginated"
  def list(user, opts \\ [])

  @doc "Unread count — used for the nav badge"
  def unread_count(user)

  def mark_read(notification)
  def mark_all_read(user)
end
```

---

### How consuming contexts use the system

Each context calls `Notifications.dispatch/3` directly — no context-specific notifier module is needed unless the context wants to wrap the call with domain-specific logic:

```elixir
# In AutomationExecution, on run failure:
Notifications.dispatch(user, "automation_failure", %{
  automation_id: run.automation_id,
  automation_name: automation.name,
  run_id: run.id
})
```

To add a new notification type from another context (e.g. `CollectionSessionCompleted`):
1. Create `lib/premiere_ecoute/notifications/types/collection_session_completed.ex` implementing `NotificationType`
2. Register it in `NotificationRegistry`
3. Call `Notifications.dispatch(user, "collection_session_completed", %{...})` from the Collections context

No changes to `Dispatcher`, `Notification` schema, or any other core file.

---

### Future extensions

- **Per-user channel preferences**: a `notification_preferences` table (`user_id`, `type`, `channels jsonb`) lets users opt out of email for specific types. `Dispatcher` would merge type defaults with user overrides before delivering.
- **Throttling / digest**: high-frequency types (e.g. system announcements) could batch into a daily digest email by adding a `:email_digest` channel and a digest worker.
- **Priority levels**: add `priority/0 :: :low | :normal | :high` to the behaviour for future UI filtering (e.g. only badge on high-priority types).

---

## New Oban Queue

```elixir
# config.exs
queues: [
  sessions: 1,
  twitch: 1,
  spotify: 1,
  radio: 1,
  automations: 5   # up to 5 concurrent automation runs per node
]
```

---

## File Structure

```
lib/premiere_ecoute/
  automations.ex                                    # Public context (create/update/delete/trigger)
  automations/
    automation.ex                                   # Schema: playlist_automations (embeds steps)
    automation_run.ex                               # Schema: automation_runs (embeds step results)
    action.ex                                       # @behaviour Action
    action_registry.ex                              # Compile-time action registry
    actions/
      empty_playlist.ex
      add_tracks_from_playlist.ex
      remove_duplicates.ex
      remove_tracks_by_release_date.ex
      remove_tracks_by_added_date.ex
    services/
      automation_creation.ex                        # CRUD: create/update/delete; calls scheduling service
      automation_execution.ex                       # Core run logic (called by worker)
      automation_scheduling.ex                      # schedule/1, cancel/1, next_run_at/1
      history_pruning.ex                            # Prune old runs
    workers/
      automation_runner.ex                          # Oban worker: schedule next, then execute
      history_pruner.ex                             # Oban Cron (daily): prune run history
  notifications.ex                                  # Public context (dispatch, list, mark_read)
  notifications/
    notification.ex                                 # Schema: user_notifications
    notification_type.ex                            # @behaviour NotificationType
    notification_registry.ex                        # Compile-time type registry
    dispatcher.ex                                   # Persist + route to channels
    channels/
      in_app_channel.ex                             # PubSub broadcast
      email_channel.ex                              # Stub → Accounts.Mailer (future)
      twitch_chat_channel.ex                        # Stub → Apis.twitch() (future)
    types/
      automation_failure.ex                         # First registered type

priv/repo/migrations/
  _create_playlist_automations.exs
  _create_automation_runs.exs
  _create_user_notifications.exs
```

---

## Migration Order

1. `create_playlist_automations`
2. `create_automation_runs`
3. `create_user_notifications`

---

## UI

### New pages

All routes added to the `/playlists` scope in the router, under a new `live_session :automations` with `:viewer` auth (consistent with existing playlist routes).

```elixir
# router.ex — inside scope "/playlists"
live_session :automations, on_mount: [{UserAuth, :viewer}] do
  live "/automations",          Playlists.AutomationsLive,        :index
  live "/automations/new",      Playlists.AutomationFormLive,     :new
  live "/automations/:id",      Playlists.AutomationLive,         :show
  live "/automations/:id/edit", Playlists.AutomationFormLive,     :edit
end
```

---

#### `/playlists/automations` — `AutomationsLive` (index)

List of all user automations.

- Each row: name, schedule summary (e.g. "Every 1st of the month at 09:00"), enabled/disabled badge, last run status + time ago, next run time (or "Manual"), action buttons
- Action buttons per row: **Run now**, **Edit**, **Enable/Disable toggle**, **Delete**
- "Run now" triggers an immediate `AutomationRunWorker` job and flashes confirmation
- "Delete" shows inline confirmation before deleting
- Empty state with CTA to create the first automation
- "New automation" primary button in page header

---

#### `/playlists/automations/new` and `/playlists/automations/:id/edit` — `AutomationFormLive`

Single form page used for both create and edit (`:new` / `:edit` live action).

**Sections:**

1. **Details** — name (required), description (optional)
2. **Schedule** — radio group: Manual / Once / Recurring
   - `once`: datetime picker — passed to `AutomationScheduling.schedule/2` at save time, stored only in the Oban job
   - `recurring`: text input for cron expression + live human-readable preview (e.g. `"0 9 1 * *"` → "At 09:00 on day 1 of every month")
3. **Steps builder**
   - Ordered list of steps; each step shows: position badge, action type label, config summary
   - "Add step" button → modal or inline selector: pick action type from registry → renders dynamic config fields for that action
   - Up/down reorder buttons per step
   - Delete button per step
   - Config forms per action type (all use library playlists from the user's library as selects):
     - `empty_playlist` → playlist select
     - `add_tracks_from_playlist` → source playlist select + target playlist select
     - `remove_duplicates` → playlist select
     - `remove_tracks_by_release_date` → playlist select + number input "older than N days"
     - `remove_tracks_by_added_date` → playlist select + number input "older than N days"

**Footer buttons:** Save / Save & Run (triggers run immediately after save)

---

#### `/playlists/automations/:id` — `AutomationLive` (show)

**Header:** name, schedule summary, enabled/disabled toggle, Edit button, Delete button, "Run now" button.

**Steps section (read-only):** ordered list of steps with action type label + config summary. Shows what the automation will do at a glance.

**Run history:** table of past runs, most recent first, paginated.

| Trigger | Status | Started | Duration |
|---|---|---|---|
| Scheduled | ✅ Completed | 1 Apr 09:00 | 3s |
| Manual | ❌ Failed (step 2) | 15 Mar 14:22 | 1s |

- Clicking a row expands inline to show per-step results:
  - Position, action type, status badge, output summary (e.g. "Removed 12 tracks"), error message on failure
  - Skipped steps shown in muted style

- The run history table subscribes to `"automation:#{id}"` PubSub so in-progress runs update live (status transitions, step completions)

---

### Existing pages — additions

#### `PlaylistLive` (`/playlists/:id`)

Add an **Automations** section below the track list.

- Shows automations that reference this playlist's `playlist_id` in any step config
- Each entry: automation name, schedule summary, last run status, link to the automation show page
- "Create automation for this playlist" shortcut link → navigates to `/playlists/automations/new` with the playlist pre-selected in the first step

#### `LibraryLive` (`/playlists`)

Add a small **automations count badge** on each playlist card (e.g. "2 automations") that links to the playlist detail page.

---

### Notification UI — additions to layout

Notifications are persisted to `user_notifications` regardless of whether the streamer is online. The UI reads from the DB on mount so offline streamers see missed notifications when they next log in; PubSub is only for live updates during an active session.

On mount:
1. Query `user_notifications` for unread notifications (ordered by `inserted_at DESC`)
2. Subscribe to `"user:#{user_id}"` PubSub topic

On `{:notification, :automation_failure}` PubSub message (online only):
- Prepend the new notification to the in-memory list (already persisted to DB by `Notifier`)
- Show a **toast** with the failure message and a link to the run

UI elements:
- **Notification bell** in the nav (top bar): unread count badge driven by the loaded list
- Clicking opens a **dropdown** listing recent unread notifications: title, body, relative time, link to `/playlists/automations/:id`
- "Mark all read" action calls `Notifications.mark_all_read(user)` and clears the badge

This requires a small addition to the authenticated layout and a `NotificationsComponent` live component that owns its own DB query and PubSub subscription.

---

### File structure additions

```
lib/premiere_ecoute_web/live/playlists/
  automations_live.ex                    # /playlists/automations (index)
  automation_live.ex                     # /playlists/automations/:id (show + run history)
  automation_form_live.ex                # /playlists/automations/new|:id/edit
  components/
    automation_components.ex             # step builder, run history row, step result row

lib/premiere_ecoute_web/live/
  components/
    notifications_component.ex           # notification bell + dropdown, live PubSub
```

---

## Build Order

- [ ] 1. Migrations (3 tables)
- [ ] 2. `NotificationType` behaviour + `NotificationRegistry`
- [ ] 3. `Notification` schema + `Dispatcher` + channel stubs (`InAppChannel`, `EmailChannel`, `TwitchChatChannel`)
- [ ] 4. `Notifications` public context (`dispatch`, `list_unread`, `unread_count`, `mark_read`, `mark_all_read`)
- [ ] 5. `Automation` schema (with embedded `steps` jsonb)
- [ ] 6. `AutomationRun` schema (with embedded `steps` jsonb)
- [ ] 7. `Action` behaviour + `ActionRegistry`
- [ ] 8. Initial action implementations (5 actions)
- [ ] 9. `AutomationScheduling` service (`schedule/1`, `cancel/1`, `next_run_at/1`)
- [ ] 10. `AutomationCreation` service (CRUD; calls `AutomationScheduling.cancel` + `schedule` on changes)
- [ ] 11. `AutomationExecution` service (pipeline fold logic; calls `Notifications.dispatch` on failure)
- [ ] 12. `AutomationRunWorker` (schedule next → insert run → execute steps)
- [ ] 13. `HistoryPruningService` + `HistoryPrunerWorker` (Oban Cron daily)
- [ ] 14. `Notifications.Types.AutomationFailure` type module + register in `NotificationRegistry`
- [ ] 15. `Automations` public context module
- [ ] 16. Router: add automations routes to `/playlists` scope
- [ ] 17. `AutomationsLive` (index) + `AutomationComponents`
- [ ] 18. `AutomationFormLive` (new/edit) with dynamic step builder
- [ ] 19. `AutomationLive` (show + live run history)
- [ ] 20. `PlaylistLive` — add automations section
- [ ] 21. `LibraryLive` — add automation count badges
- [ ] 22. `NotificationsComponent` — notification bell, dropdown, toast in layout

---

## Concrete Example

**Scenario**: "Monthly fresh playlist" — every month, rebuild a "Fresh picks" playlist by copying tracks from a "Inbox" playlist then removing anything released more than 90 days ago.

### Automation record

```elixir
%Automation{
  id: 42,
  user_id: "usr_abc",
  name: "Monthly fresh playlist",
  description: "Rebuild Fresh picks from Inbox, keep only recent releases",
  enabled: true,
  schedule_type: :recurring,
  cron_expression: "0 9 1 * *",   # 09:00 on the 1st of each month
  next_run_at: ~U[2026-04-01 09:00:00Z],  # virtual field — loaded from oban_jobs on demand
  steps: [
    %{"position" => 1, "action_type" => "empty_playlist",
      "config" => %{"playlist_id" => "lp_fresh_picks"}},
    %{"position" => 2, "action_type" => "add_tracks_from_playlist",
      "config" => %{"source_playlist_id" => "lp_inbox", "target_playlist_id" => "lp_fresh_picks"}},
    %{"position" => 3, "action_type" => "remove_tracks_by_release_date",
      "config" => %{"playlist_id" => "lp_fresh_picks", "older_than_days" => 90}}
  ]
}
```

### Action implementation (`remove_tracks_by_release_date`)

```elixir
defmodule PremiereEcoute.Automations.Actions.RemoveTracksByReleaseDate do
  @behaviour PremiereEcoute.Automations.Action

  alias PremiereEcoute.Apis

  @impl true
  def id(), do: "remove_tracks_by_release_date"

  @impl true
  def validate_config(%{"playlist_id" => _, "older_than_days" => days})
      when is_integer(days) and days > 0,
      do: :ok

  def validate_config(_), do: {:error, ["playlist_id is required", "older_than_days must be a positive integer"]}

  @impl true
  def execute(%{"playlist_id" => playlist_id, "older_than_days" => days}, _context, scope) do
    cutoff = Date.add(Date.utc_today(), -days)

    with {:ok, tracks} <- Apis.spotify().get_playlist_tracks(scope, playlist_id),
         stale = Enum.filter(tracks, &(release_date(&1) < cutoff)),
         {:ok, _} <- remove_tracks(scope, playlist_id, stale) do
      {:ok, %{removed_count: length(stale)}}
    end
  end

  defp release_date(%{release_date: date}), do: date
  defp remove_tracks(_scope, _id, []), do: {:ok, nil}
  defp remove_tracks(scope, id, tracks), do: Apis.spotify().remove_playlist_items(scope, id, tracks)
end
```

### Run record after execution

```elixir
%AutomationRun{
  id: 99, automation_id: 42,
  status: :completed, trigger: :scheduled,
  started_at: ~U[2026-04-01 09:00:01Z],
  finished_at: ~U[2026-04-01 09:00:04Z],
  steps: [
    %{"position" => 1, "action_type" => "empty_playlist",
      "status" => "completed", "output" => %{"removed_count" => 47}, "error" => nil,
      "started_at" => "2026-04-01T09:00:01Z", "finished_at" => "2026-04-01T09:00:02Z"},
    %{"position" => 2, "action_type" => "add_tracks_from_playlist",
      "status" => "completed", "output" => %{"added_count" => 47}, "error" => nil,
      "started_at" => "2026-04-01T09:00:02Z", "finished_at" => "2026-04-01T09:00:03Z"},
    %{"position" => 3, "action_type" => "remove_tracks_by_release_date",
      "status" => "completed", "output" => %{"removed_count" => 12}, "error" => nil,
      "started_at" => "2026-04-01T09:00:03Z", "finished_at" => "2026-04-01T09:00:04Z"}
  ]
}
```

Step 2's `output` is merged into context, so step 3 executes with `context = %{"removed_count" => 47, "added_count" => 47}`.

If step 2 had failed, `steps` would contain `status: "failed"` for step 2, `status: "skipped"` for step 3, the run `status` would be `:failed`, and a `user_notifications` row would be inserted with `data: %{automation_id: 42, run_id: 99}`.

---

## Decisions

- **Parallel runs**: allowed — no guard against concurrent runs of the same automation.
- **Edit while running**: allowed — `automation.steps` is snapshotted into the run at the moment `AutomationRunWorker` starts, so edits to the automation mid-run have no effect on the in-progress execution.
- **Context injection**: flat merge of all previous outputs; last-write-wins on key collision; no templating DSL in config.
