# Feature design — Wantlist v2: "Build your playlist live"

> **Status:** First draft — for discussion, not yet agreed
> **Type:** Extension of the existing `PremiereEcoute.Wantlists` context + new capture surfaces
> **Audience:** Internal — product & implementation. The streamer-facing pitch for the
> same feature is [`wantlist.md`](wantlist.md); keep the two in sync when decisions change.
> **Author:** Draft, September 2026

---

## 1. The pitch, in one paragraph

Your viewers discover music on your stream. Right now, when a track hits, they
have exactly two options: grab their phone, fight the Spotify search bar, and
stop watching you — or forget the track forever. **Wantlist v2 makes the third
option the easy one: they type one word in your chat, and the track lands in
*their own* Spotify playlist before the chorus is over.** No tab switch, no
search, no "what was that track again?" in the VOD comments. And you get a live
readout of exactly which tracks your community wanted to keep.

---

## 2. The problem we are actually solving

> **"I want to build my playlist live, while listening to the stream."**

That's the whole thing. Everything in this document exists to make that one
sentence true with the least possible friction.

Today, for a viewer, that sentence costs about 40 seconds and full attention:

| Step | Cost |
|---|---|
| Notice the track | free |
| Find its name (overlay? ask chat? Shazam?) | 5–20s, often fails |
| Open Spotify, search, disambiguate the right version | 15–30s |
| Add to the right playlist | 5–10s |
| Come back to the stream | attention already gone |

Multiply by 15 tracks in a listening session. Nobody does it. The music gets
discovered and then immediately lost — which is a bad outcome for the viewer
(no playlist), for the streamer (no evidence their curation worked), and for
the artist (a play that never converted into a save).

### What the streamer loses today

- **No proof of impact.** You know the chat said "🔥". You don't know that 62
  people kept the track.
- **No recurring artifact.** Every stream's discoveries evaporate at the end of
  the stream. There is no object your community goes back to during the week.
- **No leverage with labels/artists.** "My chat liked it" is not a pitch.
  "148 saves in 2 hours, 71 % of them from first-time listeners" is.

---

## 3. What already exists (we are not starting from zero)

A substantial part of the machinery is already shipped and in production. This
proposal is mostly about **connecting existing pieces and lowering friction**,
not building a new product.

| Capability | Where it lives today | State |
|---|---|---|
| Personal wantlist (albums / tracks / artists) | `PremiereEcoute.Wantlists`, `wantlists` + `wantlist_items` tables | ✅ shipped |
| Automatic Spotify ingestion of unknown tracks | `Wantlists.Services.AddTrack` | ✅ shipped |
| `!save` chat command (saves the track currently playing) | `Sessions.Scores.CommandHandler` | ✅ shipped |
| Per-streamer toggle for `!save` | `profile.chat_settings.save_wantlist` | ✅ shipped |
| Heart button on the radio page & discography pages | `Wantlist.WantlistLive`, radio pages | ✅ shipped |
| Bell notification on save | `Notifications.Types.WantlistSave` | ✅ shipped |
| Domain events | `AddedToWantlist`, `RemovedFromWantlist` (event store) | ✅ shipped |
| REST API (`GET /api/wantlist`, `POST /api/wantlist/tracks/current`, `DELETE /api/wantlist/items/:id`) | `Api.Wantlist.*Controller` | ✅ shipped |
| MCP tools (`list`, `add`, `remove`, `save_current_track`) | `Mcp.Components.Wantlist.*` | ✅ shipped |
| Twitch extension panel (now-playing + like button) | `apps/extension`, `Api.Extension.WidgetController` | ⚠️ shipped but **stubbed** — `like_track/2` always returns `:no_playlist_rule` |
| Chat vote pipeline (Broadway, batched writes, live PubSub) | `Sessions.Scores.MessagePipeline` | ✅ shipped (used for scoring, reusable for saves) |

### The one gap that matters

**A wantlist is not a playlist.** Today the wantlist is a page on
premiere-ecoute.fr with links out to Spotify/Deezer/Tidal. The viewer still has
to re-do the work in their music app. We solved "remember the track" — we did
**not** solve "build my playlist".

Closing that gap is §5.1, and it is the heart of this proposal.

---

## 4. The proposal in one picture

```
   During the stream                          In the viewer's world
   ─────────────────                          ──────────────────────
                                    ┌──────────────────────────────┐
  chat: "!save"        ─┐           │                              │
  chat: <streamer emote>─┤          │   Spotify / Deezer playlist  │
  chat: "banger"        ─┼──►  Wantlist  ──sync──►  "🎧 <channel> — Sept 2026"
  chat: personal word   ─┤     (capture)            (auto-created, auto-appended)
  extension ❤️ panel    ─┤           │                              │
  Stream Deck / API     ─┤           └──────────────────────────────┘
  MCP ("save that one") ─┘
                              │
                              ├──► live overlay: "23 saves for this track"
                              └──► end-of-stream recap + community playlist
```

One capture concept (`save`), many input surfaces, one guaranteed outcome:
**a real playlist in the viewer's own music account, filled in real time.**

---

## 5. Feature set

### 5.1 Live playlist sync — *the core*

The viewer connects Spotify (or Deezer) once. From then on, every wantlist save
is appended to a real playlist in their account, within seconds.

- **Target playlist strategy** (viewer setting, default = *per channel, per month*):
  - `per_channel_month` — `🎧 <channel> — September 2026` (default; keeps
    playlists a digestible size and gives them a natural "era")
  - `per_session` — one playlist per listening session / stream
  - `single` — one forever-growing "Premiere Ecoute" playlist
  - `existing` — append to a playlist the viewer already owns
- **Auto-created on first save**, named and described automatically, with the
  channel name and date. The viewer never has to set anything up beyond the
  one-time provider connection.
- **Appended live** — the track appears in their Spotify app while the stream is
  still playing it. This is the moment that sells the feature.
- **Deduplicated** — saving the same track twice is a no-op, not a duplicate row.
- **Reconciled** — a background worker retries failed appends (token expiry,
  rate limit, offline provider) so a save is never silently lost.
- **Still works without a provider connection.** The wantlist remains the source
  of truth; sync is an enrichment. A viewer with no Spotify link keeps the
  existing behaviour (wantlist page + export links), and the moment they
  connect, we backfill.

> **Design principle:** the wantlist is ours and always works; the playlist is
> theirs and is a projection of the wantlist. We never make the feature depend
> on a third party being up.

### 5.2 Capture surfaces — *"vote to save" from anywhere*

The single most important variable is **how many keystrokes a save costs**. All
of these resolve to the same command: *save whatever is playing right now on
this channel to my wantlist*.

#### a) Chat — command (shipped)

`!save` → replies in-thread with confirmation. Works today, per-channel toggle.

#### b) Chat — emote save *(new)*

The streamer picks **one emote** (a channel emote, a sub emote, or a global one)
as the save trigger. A message whose content is *just that emote* is a save.

```
<viewer> premiereHeart
<bot>    @viewer "Midnight City" saved to your wantlist ❤️
```

Why it matters: emotes are the native vocabulary of a Twitch chat. Spamming a
channel emote when a track slaps is something your chat **already does**. We
turn an existing reflex into a playlist entry — zero new behaviour to teach.

Configurable: `n` repeats of the emote still counts once; emote save can be
restricted to subs/followers if the streamer wants.

#### c) Chat — keyword save *(new)*

The streamer defines one or more plain-text keywords: `banger`, `+1`, `save`,
`pépite`, `dans la playlist`. Matching is exact-token and case-insensitive,
reusing the same matching discipline as the existing vote parser
(`Vote.from_message/2` — token boundaries, no false positives inside longer
words).

Why it matters: it lets the trigger be **part of the channel's culture** rather
than a bot command. A chat that yells "PÉPITE" already votes; it just doesn't
know it yet.

#### d) Chat — per-viewer personal keyword *(new)*

Each **viewer** can register their own trigger word in their account settings
(e.g. `mine`, `keep`, `🎯`). It works in any channel that has chat capture
enabled.

Why it matters: power users who watch several music channels get one muscle
memory that works everywhere, and it can be a word that doesn't collide with
the channel's own chat noise. It also creates a light personalisation hook —
people like having *their* word.

> **Precedence** when several rules could match one message: personal keyword →
> channel keyword → channel emote → `!save` command. First match wins, one save
> per message, always idempotent per (viewer, track).

#### e) Twitch extension panel *(finish what's started)*

The panel already shows the now-playing track. It needs its ❤️ button wired to
the wantlist (today it dead-ends on `:no_playlist_rule`).

- One tap, no chat, no typing — works on **mobile Twitch**, where typing in chat
  during a stream is painful and where a large share of the audience is.
- Shows the viewer's save count for the session, and a "connect your Spotify"
  call to action for viewers not yet linked.
- Because the panel is authenticated with the Twitch extension JWT, a viewer who
  has linked their Twitch identity to a Premiere Ecoute account needs **zero
  login** in the iframe.

#### f) App / web *(extend)*

- Radio page & session page: heart button (shipped).
- Session recap page: "save all", "save the top 5 of this stream".
- Mobile app (`apps/mobile`): wantlist tab + push notification on save.

#### g) REST API *(shipped, document & extend)*

`POST /api/wantlist/tracks/current?broadcaster_id=…` already does the job.
This is what makes a **Stream Deck key**, an OBS dock, a Discord bot or a
community-built tool a one-line integration. Add: bulk save, save by Spotify ID,
session-scoped save history.

#### h) MCP *(shipped, extend)*

Tools already exist for list/add/remove/save-current-track. This is the
"assistant" surface:

> *"Add everything I saved from <channel> last night to a new playlist called
> Autumn Digging, and drop the two ambient ones."*

Extend with: `wantlist.sync_to_playlist`, `wantlist.session_saves`,
`wantlist.top_saved` so an assistant can do real curation work on top of the
raw captures.

### 5.3 What the streamer gets back

Capture is for the viewer. This part is what makes a streamer *turn it on*.

- **Live save counter** per track, on the dashboard and as an **OBS overlay**
  ("❤️ 23 saves") — reusing the existing session PubSub broadcast path.
- **Track leaderboard** for the stream: which tracks were kept, by how many, how
  fast (saves in the first 30 seconds = an instant hit).
- **End-of-stream recap**, auto-posted in chat and available as a page:
  *"Tonight's most saved: 1. … 2. … 3. …"*.
- **Community playlist**: a channel playlist auto-built from the crowd's saves,
  ranked by save count. This is a weekly artefact your community can subscribe
  to — the repo already has playlist subscriptions and notifications
  (`Playlists.PlaylistSubscription`, `PlaylistNotification`) to distribute it.
- **Discovery credit**: a per-channel "saves generated" counter — a real,
  quotable number for sponsorships, label relations and artist outreach.

---

## 6. Why a streamer should switch it on

| Objection | Answer |
|---|---|
| "More setup work for me" | One toggle in account settings, plus optionally choosing an emote/keyword. Under 60 seconds. Nothing to install, nothing in OBS unless you want the overlay. |
| "My chat won't learn a new command" | They don't have to. Emote save and keyword save use what your chat *already* spams. |
| "It pulls people away from my stream" | The opposite: the whole point is that they never leave the tab. Today they open Spotify and lose you. |
| "What do I actually get?" | Live proof your curation lands, a weekly community playlist that brings people back between streams, and a number you can show a sponsor. |
| "Is it another paid platform?" | No. It's part of Premiere Ecoute, which you already use for sessions and votes. |
| "Does it work for non-registered viewers?" | Partially, and we're fixing that — see §8.3. Registered viewers get the full loop. |

**The 60-second setup:** Account → Features → Chat → enable *Save to wantlist* →
pick your emote and/or keyword → done. The overlay and the recap are opt-in
extras.

---

## 7. Domain model

Everything below extends the existing `PremiereEcoute.Wantlists` context; no new
bounded context is required. Conventions follow `docs/coding_standards.md` and
the `PremiereEcouteCore.Aggregate` / event-store patterns already used.

### 7.1 Schema changes

**`wantlist_items` — add capture provenance**

| Field | Type | Notes |
|---|---|---|
| `source` | enum | `:web \| :chat_command \| :chat_emote \| :chat_keyword \| :extension \| :api \| :mcp` |
| `broadcaster_id` | belongs_to User, nullable | which channel the save came from |
| `session_id` | belongs_to ListeningSession, nullable | which listening session, if any |
| `saved_at` | utc_datetime | capture time (distinct from `inserted_at` for backfills) |

This is what makes §5.3 (leaderboards, recaps, per-channel credit) queryable at
all, and it's cheap to add now.

**`wantlist_sync_targets` — new**

| Field | Type | Notes |
|---|---|---|
| `user_id` | belongs_to User | the viewer |
| `provider` | enum | `:spotify \| :deezer` |
| `strategy` | enum | `:per_channel_month \| :per_session \| :single \| :existing` |
| `broadcaster_id` | belongs_to User, nullable | for per-channel strategies |
| `playlist_id` | string | provider playlist id |
| `period` | string, nullable | e.g. `2026-09` for the monthly strategy |
| `status` | enum | `:active \| :paused \| :revoked` (revoked = provider token gone) |

**`wantlist_syncs` — new (one row per item→playlist append)**

| Field | Type | Notes |
|---|---|---|
| `wantlist_item_id` | belongs_to WantlistItem | |
| `target_id` | belongs_to WantlistSyncTarget | |
| `status` | enum | `:pending \| :synced \| :failed \| :skipped` |
| `provider_track_id` | string | resolved track URI |
| `error` | string, nullable | last failure reason |
| `attempts` | integer | retry counter |

Unique index on `(target_id, provider_track_id)` gives deduplication for free.

**`chat_settings` (streamer profile) — add**

```elixir
field :save_emote, :string          # e.g. "premiereHeart"
field :save_keywords, {:array, :string}, default: []
field :save_restrict_to, Ecto.Enum, values: [:everyone, :followers, :subscribers], default: :everyone
field :save_overlay_enabled, :boolean, default: false
```

**Viewer profile — add**

```elixir
field :personal_save_keyword, :string   # works across all enabled channels
```

### 7.2 New modules

```
lib/premiere_ecoute/wantlists/
  wantlist_sync_target.ex              # aggregate
  wantlist_sync.ex                     # aggregate
  services/
    capture.ex                         # one entry point for every surface
    playlist_sync.ex                   # wantlist item -> provider playlist
    target_resolution.ex               # strategy -> concrete playlist (create if needed)
  chat/
    save_matcher.ex                    # emote / keyword / personal-keyword matching
    save_pipeline.ex                   # Broadway consumer of MessageSent
  workers/
    playlist_sync_worker.ex            # Oban: append + retry with backoff
    session_recap_worker.ex            # Oban: end-of-stream recap + community playlist
```

### 7.3 Events

```elixir
%TrackSaved{id: user_id, source: :chat_emote, broadcaster_id: …, session_id: …, record_id: …}
%WantlistSynced{id: user_id, provider: :spotify, playlist_id: …, track_id: …}
%WantlistSyncFailed{id: user_id, provider: :spotify, reason: …}
```

`AddedToWantlist` / `RemovedFromWantlist` stay as-is; `TrackSaved` carries the
richer capture context so read models (leaderboard, recap, analytics) can be
projected without touching the write path.

### 7.4 Capture flow

```
MessageSent (EventSub webhook)
   │
   ├─► Sessions.Scores.MessagePipeline   (existing — scores/votes)
   └─► Wantlists.Chat.SavePipeline       (new — Broadway, same producer pattern)
          │  SaveMatcher.match(message, channel_config, viewer_config)
          │     → :no_match | {:save, :emote|:keyword|:personal}
          ▼
       Wantlists.Services.Capture.save_current_track(viewer, broadcaster, source)
          │  (resolves now-playing via Apis.cache(:spotify).get_playback_state/2,
          │   exactly like CommandHandler does today)
          ▼
       WantlistItem.add/3  ──► %TrackSaved{} ──► PlaylistSyncWorker (Oban)
                                              └► PubSub "session:<id>" → overlay + dashboard
```

**Reuse, don't duplicate:** `Capture` becomes the single implementation that
`CommandHandler` (`!save`), the extension controller, the REST controller and
the MCP tool all call. Today each of those re-implements a slightly different
version of the same `with` chain.

### 7.5 Emote capture needs a webhook change

`Webhooks.TwitchController.handle/1` currently keeps only
`event.message.text`. Twitch EventSub `channel.chat.message` also delivers
`message.fragments`, with `type: "emote"` entries carrying the emote id and
name. Emote-based capture should match on **fragments**, not on the raw text, so
that a viewer typing the literal string `premiereHeart` (without it rendering as
an emote) doesn't count, and so we can tell channel emotes from global ones.

→ Add `fragments` to `%MessageSent{}` and populate it in the webhook parser.
This is a small, self-contained change and a prerequisite for §5.2(b).

---

## 8. Hard problems / decisions to make

### 8.1 Provider rate limits and quota

A 200-viewer session where 60 people save a track produces 60 playlist appends
within seconds, each on a different user's OAuth token. Spotify rate-limits
per-app, not per-user, so this is a real ceiling.

Mitigations to decide on:
- **Batch per viewer per window** (e.g. flush every 15–30 s, or on track change)
  instead of one API call per save — one call with N URIs, not N calls.
- Oban queue with bounded concurrency + exponential backoff on `429`, honouring
  `Retry-After`.
- Degrade gracefully: the wantlist row is written immediately and is the source
  of truth; the playlist append is eventually consistent. The viewer-facing
  promise is "within a minute", not "instantly", even though it will usually be
  instant.
- Check the current Spotify app quota mode (dev mode caps users at 25 — this
  must be resolved before any public rollout that depends on viewer tokens).

### 8.2 Abuse and spam

- Cooldown per (viewer, channel): at most one save per N seconds.
- One save per (viewer, track) — enforced by the existing unique index.
- Optional `save_restrict_to: :followers | :subscribers`.
- Emote-save should ignore messages from banned/timed-out users (EventSub
  already excludes them) and respect the streamer's global toggle.

### 8.3 Unregistered viewers — the biggest funnel leak

Today, `!save` from a viewer with no Premiere Ecoute account returns
*"Register on premiere-ecoute.fr to save tracks!"* — i.e. the moment of highest
intent produces a chore. Options to decide between:

1. **Shadow wantlist + claim flow (recommended).** Save against the Twitch user
   id into a pending wantlist. Reply with a one-time claim link. On first login
   with that Twitch identity, the pending saves are merged. Nothing is lost, and
   the viewer sees their reward *before* paying the signup cost.
2. Reply-with-link only (status quo).
3. Nothing — silent no-op.

Option 1 needs a retention policy (e.g. pending saves expire after 30 days) and
a GDPR position on storing Twitch ids for non-users. Worth doing: this is
plausibly where most of the growth is.

### 8.4 Track resolution quality

`AddTrack` already handles "not in our discography → fetch from Spotify → create
Single or Album". Remaining edge cases: region-locked tracks, the wrong version
(remaster vs original), and non-Spotify targets (a Deezer sync needs
cross-provider matching, which the repo does partially via `provider_ids`).
Decide whether v2 ships **Spotify-only sync** (recommended) with Deezer/Tidal as
export-only, as today.

### 8.5 Twitch extension review

Wiring the ❤️ button changes the extension's behaviour and will need a new
review pass, plus a privacy-policy line about linking Twitch identity to a
Premiere Ecoute account. Lead time on Twitch review should be assumed to be
weeks, so start the submission early if the panel is in scope.

---

## 9. Surface-by-surface spec (draft)

| Surface | Interface | Status |
|---|---|---|
| Chat command | `!save` | shipped |
| Chat emote | channel-configured emote, matched on EventSub fragments | new |
| Chat keyword | channel-configured token list | new |
| Chat personal keyword | viewer-configured token | new |
| Twitch extension | `POST /api/extension/tracks/like` (wire to `Capture`) | stub → implement |
| REST | `GET /api/wantlist` · `POST /api/wantlist/tracks/current` · `DELETE /api/wantlist/items/:id` | shipped |
| REST (new) | `POST /api/wantlist/tracks` (by provider id) · `GET /api/wantlist/sessions/:id` · `POST /api/wantlist/sync` | new |
| MCP | `wantlist.add` · `wantlist.remove` · `wantlist.save_current_track` · `user://me/wantlist` | shipped |
| MCP (new) | `wantlist.sync_to_playlist` · `wantlist.session_saves` · `wantlist.top_saved` | new |
| Overlay | `/overlay/saves/:broadcaster_id` LiveView, PubSub-driven | new |
| Stream Deck | existing REST + API token | shipped (document it) |

---

## 10. Rollout phases

| Phase | Scope | Why this order |
|---|---|---|
| **P1 — Close the loop** | Playlist sync (Spotify, `per_channel_month` default), `Capture` service, `TrackSaved` event, capture provenance columns | This alone makes the headline promise true. Everything else is a multiplier on it. |
| **P2 — Lower the friction** | Emote save + keyword save + EventSub fragments, per-channel config UI | Biggest capture-volume increase per unit of work. |
| **P3 — Pay the streamer back** | Live save counter, overlay, end-of-stream recap, top-saved leaderboard | This is what makes streamers advocate for it. |
| **P4 — Everywhere else** | Extension ❤️ wired, personal keyword, community playlist, new MCP/REST verbs, mobile | Long tail; each is independently shippable. |
| **P5 — Growth** | Shadow wantlist + claim flow for unregistered viewers | Highest leverage, highest policy cost — do it once the loop is proven. |

---

## 11. Metrics to judge it by

- **Saves per session** and **savers / viewers** ratio (the real engagement number).
- **Save → playlist sync success rate** (must stay >99 %; it's the promise).
- **Time from save to track appearing in the provider playlist** (p50 / p95).
- **Share of saves by surface** — tells us which capture surfaces earned their build cost.
- **Return rate on community playlists** (subscriptions, replays between streams).
- **Registration conversion** from the claim flow, once P5 lands.

---

## 12. Open questions for the next draft

1. Default target-playlist strategy — per channel+month, or per session? (Draft assumes channel+month.)
2. Do we sync to Deezer in v2, or Spotify-only with Deezer as export?
3. Is the community playlist owned by the streamer's account or by a platform account?
4. Shadow wantlist for unregistered viewers: in or out of the first release?
5. Should emote save be restricted to *channel* emotes only (stronger identity, less accidental) or any emote?
6. Overlay: reuse the existing overlay stack, or a new dedicated one?
7. Pricing/limits: is playlist sync available to every streamer, or is it a differentiator for a tier?
