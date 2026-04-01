# Music Explorer — Technical Implementation

The Explorer is a spatial music discovery interface at `/explore`. The user types a query,
which opens an entity (artist, album, or Wikipedia page) as a card-based node on a React Flow
canvas. Clicking annotated names or track rows opens connected nodes, building a graph of
related entities.

---

## Architecture overview

```
Browser                         Server (LiveView)
──────────────────────────────────────────────────────
[search form] ──phx-submit──▶ handle_event("search")
                                └─ start_async(:resolve)
                                    ├─ ResolveQuery.resolve/1
                                    ├─ FetchNode.fetch/1
                                    └─ AnnotateCards.annotate/1
              ◀──push_event────  handle_async → "canvas:init"

[node click]  ──pushEvent──────▶ handle_event("open_node")
                                └─ start_async({:open_node, …})
                                    ├─ FetchNode.fetch/1
                                    └─ AnnotateCards.annotate/1
              ◀──push_event────  handle_async → "canvas:node_added"

[keep click]  ──pushEvent──────▶ handle_event("keeps:add")
              ◀──push_event────  "keeps:updated"
```

---

## Bundle isolation

The canvas uses React + React Flow, which must not be bundled into the main `app.js`.

- `assets/js/explore.js` is a **separate esbuild entry point** (configured in `config/config.exs`
  with `--jsx=automatic`). It imports the hook and sets `window.__ExploreHooks`.
- `assets/js/app.js` merges `window.__ExploreHooks` into the LiveSocket hooks map at startup:
  ```js
  const allHooks = { ...Hooks, ...(window.__ExploreHooks || {}) }
  ```
- The explore route uses a dedicated root layout (`explore_root.html.heex`) that loads
  `explore.js` **before** `app.js` (both `defer`), ensuring the hook is registered before
  LiveSocket initialises.

---

## Route and layout

```
/explore  →  live_session :explore
               root_layout: {Layouts, :explore_root}
               on_mount: [{UserAuth, :viewer}]
             live "/", ExploreLive, :index
```

`explore_root.html.heex` extends the standard root layout with:
- `<link>` for `explore.css` (React Flow styles, output of esbuild)
- `<script defer src="/assets/js/explore.js">` (before `app.js`)

---

## LiveView → React bridge (`ExploreCanvas` hook)

The canvas div carries `phx-hook="ExploreCanvas" phx-update="ignore"`.

`phx-update="ignore"` tells LiveView to never morph the DOM inside that div; React owns it
entirely after mount.

### Hook lifecycle

```
mounted()
  ├─ createRoot(this.el).render(<ExploreCanvas …/>)
  ├─ addEventListener("explorer:open_node", …)   // node hotspot clicks
  ├─ addEventListener("explorer:keep", …)        // keep button clicks
  └─ handleEvent("canvas:init" | "canvas:node_added" | "keeps:updated")

destroyed()
  ├─ removeEventListeners
  └─ root.unmount()
```

### Event buffering

React's `useEffect` registers callbacks asynchronously. Events arriving before the first
render are queued in `_pending` and flushed once `onRegister(callbacks)` is called by the
React component.

### Server → React

| push_event            | React callback      | Effect                          |
|-----------------------|---------------------|---------------------------------|
| `canvas:init`         | `onInit`            | Resets graph, runs dagre layout |
| `canvas:node_added`   | `onNodeAdded`       | Appends node, re-runs layout    |
| `keeps:updated`       | `setKeeps`          | Updates keeps panel state       |

### React → server (via native DOM events)

Clicking inside a node dispatches `CustomEvent` on the element (bubbles up to `this.el`):

| CustomEvent            | Hook forwards as `pushEvent` |
|------------------------|------------------------------|
| `explorer:open_node`   | `open_node`                  |
| `explorer:keep`        | `keeps:add`                  |

Using native `CustomEvent` (not React synthetic events) is intentional — the hook lives
outside the React tree and cannot receive React events directly.

---

## Server pipeline

### 1. Query resolution (`ResolveQuery`)

```
query string
  └─▶ DB artist match (case-insensitive)   → {:artist, %Artist{}}
  └─▶ DB album match (case-insensitive)    → {:album, %Album{}}
  └─▶ Wikipedia search fallback            → {:wikipedia, %Page{}}
```

### 2. Node building (`FetchNode`)

| Input                    | Output                                              |
|--------------------------|-----------------------------------------------------|
| `{:artist, artist}`      | Intro card (Wikipedia summary) + DB discography card + up to 3 Wikipedia section cards (Career/History/Members) |
| `{:album, album}`        | Intro card (release metadata) + tracklist card (DB tracks) |
| `{:track, track}`        | Bare node with `provider_ids` — no cards, renders as embedded player |
| `{:wikipedia, page}`     | Intro card (summary) + up to 3 Wikipedia section cards |

**DB discography card** is built from `Discography.list_albums_for_artist/1`, generating
`<div class="explorer-album-row" data-entity-id="…" data-entity-type="album">` rows. This
ensures reliable click targets independent of annotation quality.

**Wikipedia sections** are fetched in parallel via `Task.async_stream` (6 s timeout).
Section selection matches against a priority list (`@target_sections`); at most 3 section
cards are produced, one per type (discography/history/members).

### 3. Card annotation (`AnnotateCards`)

Runs on all cards of DB-backed artist nodes. Loads up to 300 artists + 100 albums from the
DB (sorted longest-name-first to prevent partial matches), then wraps occurrences in card
HTML with:

```html
<mark data-entity-id="ID" data-entity-type="TYPE" class="explorer-hotspot">name</mark>
```

Pattern: `~r/(?<![<\w\-])NAME(?![\w\-]|[^<>]*>)/u` — avoids matching inside HTML tag
attributes.

Wikipedia-fallback nodes (`entity_id: nil`) receive no annotation.

### 4. Wikipedia HTML sanitisation (`PageSection`)

Uses **Floki** (DOM parser) instead of regex to avoid PCRE recursion limit errors on large
sections (Wikipedia inlines multi-kilobyte `<style>` blocks via TemplateStyles).

Transform rules applied via `Floki.traverse_and_update/2`:

| Element                             | Action                              |
|-------------------------------------|-------------------------------------|
| `style`, `script`, `sup`, `cite`, `table`, `figure` | Removed entirely |
| `div`/`span` with class matching `references`, `thumb`, `hatnote`, `mw-editsection` | Removed entirely |
| Other `div`/`span`/`section`       | Unwrapped (children kept, tag dropped) |
| `<a>`                               | Unwrapped (text kept, link dropped) |
| `<i>` with plain text content       | Annotated as search hotspot: `data-entity-id="text" data-entity-type="query"` |

The `<i>` annotation makes Wikipedia album/song titles (which Wikipedia italicises) clickable
even when the entity is not in the DB — clicking triggers a `ResolveQuery` search by name.

---

## Canvas layout

React Flow nodes are positioned with **dagre** (`rankdir: LR`, node size 440×580 px).
Layout is recomputed on every `onInit` and `onNodeAdded` call using a `graphRef` (a React
ref) that holds the current node/edge list outside the render cycle, avoiding stale-closure
issues in async callbacks.

---

## Node types

| React Flow type | Component    | Used for                          |
|-----------------|--------------|-----------------------------------|
| `artist`        | `ArtistNode` | Artists and Wikipedia pages       |
| `album`         | `ArtistNode` | DB albums (same card-stack layout)|
| `track`         | `TrackNode`  | DB tracks — shows Spotify/Deezer embed |

### Click handling in `ArtistNode`

`onClick` on the card content div uses **event delegation**:

```js
const target = e.target.closest('[data-entity-id]')
```

This covers three hotspot types with a single handler:
- `<mark data-entity-id>` — annotated entity names in prose (from `AnnotateCards`)
- `<div class="explorer-album-row" data-entity-id>` — DB discography rows
- `<li class="explorer-track-row" data-entity-id>` — DB tracklist rows
- `<i data-entity-id>` — Wikipedia italic titles (from `PageSection` sanitiser)

---

## Keeps

Keeps are stored in socket assigns (`socket.assigns.keeps`) as a list of
`%{entity_type, entity_id, label}` maps. Adding/removing syncs state back to React via
`push_event("keeps:updated", %{keeps: keeps})`. The `KeepsPanel` component renders the list
and exposes export buttons that call `pushEvent("keeps:export", %{destination, items})`.

---

## Deduplication

`socket.assigns.node_ids` tracks opened node IDs. Before starting an async fetch,
`handle_event("open_node")` checks `node_id in socket.assigns.node_ids` and no-ops if
already present. For `"query"` type nodes (Wikipedia `<i>` hotspots), `node_id` is
`"query-<label>"`, which prevents duplicate fetches for the same text.

---

## Key files

| File | Role |
|------|------|
| `lib/premiere_ecoute/explorer/node.ex` | `Node` struct |
| `lib/premiere_ecoute/explorer/card.ex` | `Card` struct |
| `lib/premiere_ecoute/explorer/services/resolve_query.ex` | DB + Wikipedia query resolution |
| `lib/premiere_ecoute/explorer/services/fetch_node.ex` | Node assembly per entity type |
| `lib/premiere_ecoute/explorer/services/annotate_cards.ex` | Entity hotspot injection |
| `lib/premiere_ecoute/apis/music_metadata/wikipedia_api/page_section.ex` | Wikipedia section fetch + Floki sanitisation |
| `lib/premiere_ecoute_web/live/explore/explore_live.ex` | LiveView — event handling, async orchestration |
| `lib/premiere_ecoute_web/live/explore/explore_live.html.heex` | Template — search bar + canvas mount point |
| `lib/premiere_ecoute_web/layouts/explore_root.html.heex` | Isolated root layout for explore bundle |
| `assets/js/explore.js` | Separate JS entry point — registers `ExploreCanvas` hook |
| `assets/js/hooks/explore_canvas.js` | LiveView hook — React lifecycle + event bridge |
| `assets/js/components/explorer/ExploreCanvas.jsx` | React root — React Flow + dagre layout |
| `assets/js/components/explorer/nodes/ArtistNode.jsx` | Card-stack node for artists/albums |
| `assets/js/components/explorer/nodes/TrackNode.jsx` | Embedded player node for tracks |
| `assets/js/components/explorer/KeepsPanel.jsx` | Keeps sidebar |
