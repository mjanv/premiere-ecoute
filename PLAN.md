# Feature: Music Explorer

## Summary

Music Explorer is a new spatial reading and listening experience at `/explore`. It turns music discovery into an active, multi-sensory navigation: instead of reading a static Wikipedia page about an artist, you move through a canvas of interconnected knowledge cards, hear tracks inline, and follow relationships outward to albums, artists, timelines, and quotes — all in the same augmented space.

The entry point is a question-first interface. Everything is framed as a query: typing "Daft Punk" is just a shorthand for "Tell me about Daft Punk." The system routes the question to the most relevant source (Wikipedia, internal discography, interviews), parses it into cards, and opens the first node on the canvas.

This is not a search feature. It is an exploration experience where reading, listening, and connecting happen simultaneously.

---

## Goals

- Give authenticated users (streamers and viewers) a free, non-linear way to discover music
- Bridge reading about music and hearing it, without leaving the same view
- Surface the relational structure of music (influences, collaborators, discography, eras) as a navigable spatial graph
- Feed discovery back into the existing workflow (wantlist, album pick pool) at session end, on demand

---

## Non-goals (v1)

- 3D graph view (stretch goal for a later version)
- Streamer playback controls (full Spotify integration is reserved for stream sessions)
- Shareable or persistent exploration paths
- AI-generated content or synthesis — the system routes and surfaces, it never generates

---

## User flow

1. Authenticated user navigates to `/explore`
2. A question-first input is shown: "What do you want to explore?"
3. User types an artist name, album, or open question
4. The system resolves the query to a primary source (internal discography + cached Wikipedia/external content)
5. A first node opens on the canvas — structured as semantic cards (intro, discography, influences, quotes, etc.)
6. Entity mentions within cards (album names, artist names, years) are annotated as interactive hotspots
7. Clicking a hotspot opens a new node side-by-side on the canvas, connected by a visible edge
8. Track/album nodes include an embedded Spotify or Deezer player (iframe embed, no direct API control)
9. As exploration continues, the canvas grows with nodes and edges — panning and zooming is supported
10. At any point, the user can open a temporary "Keeps" panel and add items (albums, tracks, artists) to it
11. At session end, the user can export their keeps to their wantlist or album pick pool

---

## Canvas model

The canvas is the core UI surface. It is inspired by the Obsidian graph view: nodes are placed automatically near their parent but with semantic hints (e.g. chronological ordering for discography nodes). The user cannot freely drag nodes in v1 — placement is system-managed but spatially meaningful.

**Node types (v1):**
- `artist` — cards sourced from Wikipedia + internal discography data
- `album` — cards with tracklist, release info, embedded player node
- `track` — embedded player node (Spotify/Deezer iframe) + metadata
- `quote / interview` — a fragment from an interview, surfaced in context

**Node types (future):**
- `genre / movement`
- `event / concert`
- `user annotation`

Each node is composed of semantic **cards** (chunks of content), not a flat block of text. Cards can be:
- Intro / biography
- Discography list
- Influences
- Members / collaborators
- Quote / interview excerpt
- Timeline (chronological card sequence)

Entity mentions inside card text are annotated via NLP/regex matched against the internal discography DB (artist names, album titles, track names). Matched mentions become interactive inline hotspots that can open a new node.

---

## Content sourcing

| Entity type | Primary source | Fallback |
|---|---|---|
| Artists in internal DB | Cached Wikipedia + internal discography | Live Wikipedia fetch |
| Albums in internal DB | Internal data | Wikipedia live fetch |
| Tracks in internal DB | Internal data | None |
| Unknown entities (from open question) | Live Wikipedia fetch | None |

Content for known entities (artists, albums in the discography) is pre-fetched and cached in the DB. Unknown entities are fetched live at browse time. The system always shows real source content — no LLM-generated text.

The query routing strategy (LLM vs deterministic search) is left to evaluation during implementation. Both approaches will be prototyped and compared on accuracy and latency before a decision is made.

---

## Audio / listening

Track playback is delivered via embedded players (Spotify embed iframe, Deezer embed iframe, or equivalent). No direct Spotify API control — that is reserved for stream sessions. The embedded player is a first-class node type on the canvas, not a floating widget or inline button.

Playback is always **explicit** — nothing plays without a deliberate user action.

---

## Keep list and export

During an exploration session:
- The user can add any item (album, track, artist) to a temporary **Keeps** panel
- The panel is hidden by default, accessible via a persistent button
- It is in-session only — it does not persist across page reloads

At session end:
- The user can export their keeps to:
  - Their **Wantlist** (existing feature)
  - Their **Album Pick Pool** (existing feature)
- Export is optional and on-demand. The explorer is its own experience.

---

## Technical architecture

### Stack

- **Phoenix LiveView** drives the page: routing, auth, data loading, node state management
- **JS component** (library TBD) handles the canvas: node layout, edges, pan/zoom, embedded players
- LiveView and the JS canvas communicate via LiveView hooks and `pushEvent` / `handleEvent`
- The canvas library will be evaluated during implementation — candidates include React Flow, Cytoscape.js, D3-force, and custom WebGL/canvas. Choice will depend on node complexity and layout control needs.

### Data flow

```
User query
  -> LiveView resolves entity (internal DB lookup or live fetch)
  -> Content fetched + parsed into card structs
  -> Entity mentions annotated (regex/NLP against discography DB)
  -> Node data pushed to JS canvas via LiveView socket
  -> JS renders node cards + edges
  -> User click on hotspot -> pushEvent to LiveView
  -> LiveView resolves new entity -> pushes new node to canvas
```

### New Elixir context: `Explorer`

Responsibilities:
- `Explorer.resolve_query/1` — parse query, determine entity type, route to source
- `Explorer.fetch_node/1` — fetch and parse content for a given entity into card structs
- `Explorer.annotate_cards/1` — scan card text for discography entity mentions, return hotspot positions
- `Explorer.Node` — struct representing a canvas node (type, cards, hotspots, metadata)
- `Explorer.Card` — struct for a single semantic card within a node

### Content caching

A new `explorer_content_cache` table (or equivalent) stores pre-fetched external content per entity (artist_id, album_id). Cached content is invalidated and refreshed on a schedule. Live fetches are used for uncached entities with a timeout and graceful fallback.

---

## v1 scope

**What ships in v1:**

- `/explore` route, hard login-gated
- Question-first entry input
- Single artist node: semantic cards (intro, discography, influences, quotes)
- Entity annotation (inline hotspots for album/artist/track names from DB)
- At least one listening node type: embedded Spotify/Deezer player as a canvas node
- Canvas with 2+ nodes side-by-side, visible edges, pan/zoom
- Temporary Keeps panel with export to wantlist

**What is deferred:**

- Open question routing (v1 supports direct entity lookup only — artist name, album name)
- Interview / quote node sourcing pipeline
- Timeline card type
- 3D canvas view
- Canvas library final choice (pending evaluation spike)

---

## Open questions

1. **Canvas library selection** — needs a spike comparing React Flow, Cytoscape.js, and D3-force on: embedded iframe support inside nodes, custom card layout per node, performance with 20+ nodes.
2. **Wikipedia parsing** — evaluate MediaWiki API (structured wikitext) vs raw HTML scrape + parser for card extraction quality.
3. **Query routing strategy** — LLM vs deterministic: prototype both against a set of 20 test queries and compare precision and latency before committing.
4. **Content cache invalidation** — determine TTL and refresh strategy for cached Wikipedia content per entity type.
5. **Annotation quality** — false positive rate of regex/DB matching on artist/album names that appear as common words.

---

## Interview transcript

The following is the full interview used to produce this specification.

**Q: Tell me what the feature is — describe it in your own words, as if explaining to a teammate.**

> I want to create a new way to explore music in the most free way. Link reading and hearing and connecting. We have data sources like full discography and encyclopedia pages, and interviews and others, but not an haptic way to explore it. My first idea is to start from an entry point where I can pick an artist or ask a question, and will start reading the most relevant source (like the wikipedia page or other page). The navigation of this page is augmented for me: I can have an haptic feedback to what i'm seeing: listen to a track immediatly while i'm reading about the birth of its album. Seeing about albums can open a timeline, seeing another artist can open a new page. Reading is not seeing a big block of text, it is an experience of choices, feedbacks and navigations through relationships in the same augmented space that can be 2D or 3D.

**Q: When you say 'pick an artist or ask a question' as the entry point — are these two fundamentally different modes, or is it one unified search/query interface that handles both?**

> Question-first always. Everything is framed as a question. Searching 'Daft Punk' is just a shorthand for 'Tell me about Daft Punk'. The question interface is universal.

**Q: When you say '2D or 3D augmented space' — is 3D a stretch goal or a core design requirement from day one?**

> 3D is a stretch goal. Start 2D (a rich canvas/map), keep 3D as a future layer once the interaction model is validated.

**Q: You used the word 'haptic' specifically. Are you talking about literal device vibration (mobile), or is 'haptic' metaphorical here?**

> Metaphorical — sensory response. Haptic means instant feedback: a track plays when you hover over it, a visual pulse when you click a relationship, sound responding to navigation.

**Q: What does a single paragraph look like in this model — is the text itself modified/annotated, or is the augmentation purely around it?**

> A mix of all three: pristine text with augmentation around it, annotated interactive hotspots, and deconstructed cards. All three coexist.

**Q: When a track plays 'while you're reading about the birth of its album' — is audio triggering automatic or always explicit?**

> Always explicit. Nothing plays without deliberate intent.

**Q: Is the AI layer here for routing/summarizing existing sources, or generating new connections?**

> Routing and summarizing only. The content is always traceable to a real page. No AI-generated prose.

**Q: When you 'see another artist and open a new page' — does this replace the current view, stack on top, or open side-by-side?**

> Side-by-side in canvas. New nodes open beside the current one. The canvas expands. You can see multiple 'pages' simultaneously and pan between them.

**Q: The relationships between artists, albums, tracks — are they pre-computed or discovered dynamically?**

> Hybrid — internal first, external enriched. Internal graph is the backbone. External sources add depth (influences, collaborations) when available.

**Q: What happens when you've opened 10 nodes — is there a concept of 'session' or 'exploration path' that gets saved?**

> You can keep items (tracks, albums, artists...) but the session path is stateless.

**Q: Is this feature for the streamer only, or also for viewers browsing the site independently?**

> Viewers too — authenticated. Any logged-in user (streamer or viewer) can explore.

**Q: When a user explicitly plays a track during exploration — full Spotify integration or embed?**

> Will be through embeds (Spotify, Deezer) or other solutions, but no direct control — that feature is reserved to streamers.

**Q: For 'routing to the most relevant source' — LLM call or deterministic search?**

> Will evaluate LLM against deterministic search. Both will be prototyped before committing.

**Q: In the side-by-side canvas — when a new node opens, where does it appear? Automatic, semantic, or freeform?**

> A mix of automatic and semantic, like the graph in Obsidian.

**Q: Are there other node types beyond artists, albums, tracks, timeline, Wikipedia pages?**

> Interview / quote — a fragment from an interview, surfaced in context.

**Q: Should there be a direct 'Add to wantlist' action from within the explorer?**

> The explorer is its own experience, but the user will have the opportunity at the end to export their picks to their wantlist (among other destinations) if they want.

**Q: For external content — live fetch or crawl and cache?**

> Hybrid — cache known entities, fetch unknown ones live.

**Q: LiveView only, or open to a client-heavy approach?**

> Mix the best of both worlds. LiveView as the driver, JS (React, D3, WebGL, whatever...) as the assistant.

**Q: What's the smallest version that would be genuinely useful and worth shipping?**

> Single node rich artist page with listening nodes to "haptic" the songs.

**Q: For the annotated reading model — who identifies entity hotspots?**

> NLP / regex matched against the internal discography DB (artist names, album titles). Fast, controlled, only surfaces what we know.

**Q: Concretely, what does a listening node look like in v1?**

> Embedded player node — a full-sized node on the canvas (Spotify/Deezer embed iframe) that opens beside the article. Part of the spatial graph.

**Q: Does this feature have a name, and where does it live in the site?**

> New top-level route `/explore`.

**Q: Where is the keep list shown?**

> Temporary in-session panel. Accessible via a button but hidden by default — like a cart in e-commerce, you fill it then act at the end.

**Q: Auth gate?**

> Hard login gate. Redirect to login if not authenticated.

**Q: Canvas library in mind?**

> Open question — needs evaluation. Candidates: Cytoscape.js, React Flow, D3-force, or custom canvas/WebGL.

**Q: In v1, which reading model dominates — annotated prose or deconstructed cards?**

> Cards dominate. The article is broken into semantic chunks. Each chunk is a card. Navigation between cards is a choice, not scrolling.
