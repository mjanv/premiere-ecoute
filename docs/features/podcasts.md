# Feature spec — Podcasts (shows & episodes)

> **Status:** Design agreed, ready for implementation
> **Type:** New bounded context + new infrastructure dependency (object storage)
> **Author:** Product/architecture discussion, June 2026

## 1. Summary

Let streamers self-host podcasts on Premiere Ecoute as a cheaper alternative to a
paid podcast platform whose price point exceeds their streaming revenue. A streamer
can create one or more **shows**, and upload edited stream audio as **episodes** of a
show. Viewers can listen on the website, and — because each show is published as a
standard **RSS feed** — in any podcast app (Apple Podcasts, Spotify, Pocket Casts,
Overcast, AntennaPod, …).

The defining insight: **a podcast is an RSS feed we host, not something we upload to
Apple/Spotify.** Directories are just RSS readers with a search index. We host the
audio + the feed; the streamer submits the feed URL to each directory once, by hand;
the directories poll the feed and their apps download audio directly from our storage.
There is **no API integration** with Apple or Spotify to build.

### Why self-hosting is viable here

Expected volume: **~1 episode/week, ~100 listens/episode**. At ~80–100 MB/episode that is
**~40 GB egress/month** and ~0.4 GB/week of new storage. On an egress-cheap S3-compatible
store (Cloudflare R2 / Backblaze B2) this is effectively free, so self-hosting does not
re-introduce the platform's cost problem.

## 2. Goals / non-goals

**Goals**
- Streamers create shows and upload MP3 episodes.
- Each show is exposed as a public, spec-compliant podcast RSS feed (Apple iTunes
  namespace included) consumable by any podcast app.
- Viewers listen on the website (in-page player) and via podcast apps.
- Per-episode download/listen analytics.

**Non-goals (explicitly out of scope for v1)**
- No rating / voting / scoring of podcasts. Podcasts do **not** reuse the
  `Sessions`/`Scores` voting machinery. They are a standalone library.
- No transcoding. **MP3 only**; non-MP3 uploads are rejected.
- No automated submission to Apple/Spotify (manual, one-time, per show by the streamer).
- No paid subscriptions / private feeds / dynamic ad insertion.
- No automatic generation of episodes from streams (streamer uploads an already-edited file).

## 3. How podcasting works (reference)

Three roles. A paid platform plays all three; we play the first two.

1. **Host (us)** — stores the audio files at stable public URLs, and serves one RSS
   XML document per show at a fixed URL. The feed lists show metadata + one `<item>`
   per episode; each item carries a permanent GUID and an `<enclosure>` pointing at the
   audio URL with its byte size and MIME type.
2. **Directories / apps (Apple, Spotify, Pocket Casts, …)** — RSS readers. The streamer
   submits the feed URL once. They poll it on a schedule, surface new items, and their
   apps **download audio directly from our enclosure URL**. They are not in the audio
   data path. Supporting "open" apps is free: one correct feed works everywhere; the
   Apple iTunes tags are simply ignored by apps that don't use them.
3. **Listener** — subscribes in their app of choice or listens on our website.

### Hard requirements this drags in
- Feed URL and audio URLs must be **public and unauthenticated** (apps can't log in).
- Episode **GUIDs and enclosure URLs must be permanent** — if they change, apps show
  duplicates or re-download. This constrains storage key naming (see §6).
- Audio must support **HTTP byte-range** requests (seek/resume) — object stores do this
  natively; another reason not to proxy bytes through Phoenix.
- Feed must include Apple's **iTunes namespace** tags (author, category, explicit flag,
  per-episode `<itunes:duration>`, show cover art ≥ 1400×1400 px) or Apple rejects it.

## 4. Decisions locked

| Topic | Decision |
|---|---|
| Distribution | Self-host audio **and** RSS feed. Manual directory submission. No Apple/Spotify API. |
| Audio format | **MP3 only.** Reject other formats at upload. |
| Duration metadata | **Automatic**, via a **pure-Elixir** MP3 frame parser (no ffmpeg). |
| Feed granularity | **One RSS feed per show.** A streamer with N shows has N feeds. |
| Cover art | Each show has its **own** square cover image (≥ 1400×1400), separate from user avatar. |
| Visibility | **Public**, unauthenticated. |
| Rating/voting | **Out of scope.** Standalone library, no scores. |
| Analytics | **Yes** — per-episode download counting via a tracking redirect endpoint. |
| Storage | New **S3-compatible object storage** (provider provisioned by owner). |

## 5. Domain model — new `PremiereEcoute.Podcasts` context

Follows existing conventions: `use PremiereEcouteCore.Context`, aggregates via
`use PremiereEcouteCore.Aggregate`, events via the Event Store + EventBus.

```
lib/premiere_ecoute/podcasts.ex                 # context facade (defdelegate)
lib/premiere_ecoute/podcasts/
  show.ex                                        # aggregate
  episode.ex                                     # aggregate
  events/                                        # domain events
  services/
    audio_ingestion.ex                           # validate + probe + finalize an upload
    feed.ex                                       # RSS feed builder (read model)
  workers/
    episode_ingestion_worker.ex                  # Oban: probe duration/size, publish events
```

### `Show` aggregate

| Field | Type | Notes |
|---|---|---|
| `id` | id | PK |
| `user_id` | belongs_to User | the streamer (owner) |
| `slug` | string | URL-stable, unique per user; used in feed URL |
| `title` | string | required |
| `description` | text | shown in feed |
| `author` | string | defaults to streamer display name |
| `language` | string | e.g. `fr`, `en` (RSS `<language>`) |
| `category` | string | Apple category (constrained list) |
| `explicit` | boolean | iTunes explicit flag |
| `cover_url` | string | public URL in object storage, ≥1400² |
| `published` | boolean | feed is live / discoverable |

- `:root` preload: `[:user]`. `:identity`: `[:user_id, :slug]`.
- Feed URL: `GET /podcasts/:username/:show_slug/feed.xml` (public).

### `Episode` aggregate

| Field | Type | Notes |
|---|---|---|
| `id` | id | PK |
| `show_id` | belongs_to Show | |
| `guid` | string | **permanent, immutable**, globally unique (e.g. UUID) — RSS GUID |
| `title` | string | required |
| `description` | text | show notes |
| `audio_key` | string | object-storage key (immutable once set) |
| `audio_byte_size` | integer | RSS `<enclosure length>` |
| `duration_seconds` | integer | `<itunes:duration>`; auto-extracted |
| `status` | enum | `:uploading \| :processing \| :ready \| :failed` |
| `published_at` | utc_datetime | RSS `<pubDate>`; nil until published |

- `:root` preload: `[:show]`. Episodes appear in the feed only when `status: :ready`
  and `published_at` is set and `<=` now.
- `guid` and `audio_key` are write-once. Re-uploading audio creates a new episode,
  never mutates an existing GUID/URL.

## 6. Storage design

New S3-compatible object store (recommend **Cloudflare R2** or **Backblaze B2** for
cheap/free egress; any S3 API works). New dependency: `ex_aws` + `ex_aws_s3` (or a thin
HTTP client). New runtime config (bucket, endpoint, keys) in `config/runtime.exs`,
sourced from env — mirrors how Spotify/Twitch creds are configured.

- **Key naming (immutability is the contract):**
  - Audio: `podcasts/<show_id>/episodes/<guid>.mp3`
  - Cover: `podcasts/<show_id>/cover.<ext>` (re-upload overwrites; cover URL stability is
    less critical than audio, but cache-bust via query string if changed).
- **Direct-to-storage upload**, not through the LiveView process. Episodes are
  80–150 MB; routing bytes through `consume_uploaded_entries` (the current
  `priv/static/uploads` disk pattern used for festival posters) does **not** scale to
  audio and won't survive the ephemeral container. Use a **presigned PUT URL**: the
  LiveView/controller issues a presigned URL, the browser uploads directly to storage,
  then notifies the app to finalize.
- **Public read** on the audio objects (bucket policy / public bucket or signed-but-stable
  URLs). Enclosure URLs must be stable — prefer public-read objects over expiring signed
  URLs (a signed URL that expires breaks podcast apps).

## 7. Upload & ingestion flow

1. Streamer creates/opens a show → "New episode" form (title, description, MP3 file).
2. Client requests a presigned PUT (server validates `audio/mpeg` content-type, size cap).
3. Browser uploads MP3 directly to storage. Episode row created with `status: :uploading`.
4. On completion, app finalizes → `status: :processing`, enqueues
   `EpisodeIngestionWorker` (Oban).
5. Worker:
   - Verifies the object exists and is a real MP3 (magic bytes / `ID3` / frame header) —
     **reject non-MP3** defensively even though the client filtered.
   - Reads `audio_byte_size` from the object's `Content-Length`.
   - **Extracts `duration_seconds`.** → see decision below.
   - Sets `status: :ready`. Publishes `EpisodePublished` when the streamer publishes.

### MP3 duration extraction — **decided: pure Elixir**

MP3 duration is not in a single header for VBR files; it requires scanning frames. We
extract it with a **pure-Elixir MP3 frame parser** in the worker — **no system
dependency** (no ffmpeg/ffprobe in the runtime image), consistent with MP3-only/no-transcode.

Implementation notes for the parser:
- Skip any leading **ID3v2** tag (read its size from the 10-byte header) and trailing
  **ID3v1** (128 bytes) before frame scanning.
- Detect **VBR** via a `Xing`/`Info` (or `VBRI`) header in the first frame: if present,
  duration = `frame_count * samples_per_frame / sample_rate` — exact and cheap, no full scan.
- If no VBR header (**CBR**), duration = `(file_size - tag_bytes) * 8 / bitrate` from the
  first valid frame header.
- Last resort, if both fail: scan frames to count them. Keep this bounded.
- The streamer can **override duration manually** as a fallback if parsing fails; ingestion
  must not hard-fail solely on duration extraction.

## 8. RSS feed generation

- Built with **`xml_builder`** (already a dependency) in `Podcasts.Services.Feed` — a read
  model over `Show` + ready/published `Episode`s. No Ecto in the web layer
  (`Podcasts.feed_for(show)` returns the XML string).
- RSS 2.0 + `itunes` + `content` namespaces. Required tags: channel
  `title/description/language/link/itunes:author/itunes:category/itunes:explicit/itunes:image`;
  per item `title/description/pubDate/guid (isPermaLink=false)/enclosure (url,length,type=audio/mpeg)/itunes:duration`.
- **Caching:** the feed is cheap but polled frequently by directories. Cache the rendered
  XML (ETS or short-TTL HTTP cache headers) and invalidate on episode publish/edit.
- Served at `GET /podcasts/:username/:show_slug/feed.xml`, `Content-Type:
  application/rss+xml`, public, no auth.

## 9. Audio delivery & analytics

Because the owner wants download observability, the `<enclosure url>` in the feed points
at a **tracking endpoint in our app**, not directly at storage:

```
GET /podcasts/:username/:show_slug/episodes/:guid/audio
  -> log a download event (episode_id, ip, user-agent, timestamp)
  -> 302 redirect to the public object-storage URL
```

- The app counts every download (countable analytics); the heavy bytes + byte-range are
  served by storage after the redirect (cheap, scalable). This is the standard podcast-host
  measurement pattern.
- Store downloads as **events** (`EpisodeDownloaded`) via the Event Store, surfaced in the
  `Analytics` context / Telemetry. For honest "unique download" counts later, dedupe by
  IP+User-Agent within a 24h window (IAB-style) — can be a v1.1 refinement; v1 can store
  raw hits.
- **Website plays count as listens** (decided). The in-page player hits the same tracking
  endpoint so on-site listens and podcast-app downloads are measured uniformly. Tag the
  event with its source (`:web` vs `:feed`) so the two can still be told apart in analytics.

## 10. Web surface

Public (`pipe_through [:browser]`):
- `live "/podcasts/:username"` — a streamer's shows index.
- `live "/podcasts/:username/:show_slug"` — show page + episode list + in-page player.
- `get "/podcasts/:username/:show_slug/feed.xml"` — RSS feed (controller).
- `get "/podcasts/:username/:show_slug/episodes/:guid/audio"` — tracking redirect.

Streamer-only (`pipe_through [:browser, :require_authenticated_user]`, role `:streamer`):
- `live "/podcasts"` — my shows.
- `live "/podcasts/new"`, `live "/podcasts/:id/edit"` — show CRUD + cover upload.
- `live "/podcasts/:id/episodes/new"` — episode upload (presigned flow).
- `live "/podcasts/:id/episodes/:episode_id/edit"` — episode metadata + publish toggle.

Authorization: a show is owned by `user_id`; only the owner (or `:admin`) may
create/edit/delete. Public read for everyone.

## 11. Events & workers

Domain events (Event Store + EventBus handler registered in `config/config.exs`):
- `ShowCreated`, `ShowPublished`, `EpisodeUploaded`, `EpisodeProcessed`,
  `EpisodePublished`, `EpisodeDownloaded`.

Handler responsibilities: invalidate feed cache on publish/edit; feed analytics;
optionally notify followers (reuse `Notifications` context) on `EpisodePublished` — v1.1.

Worker: `EpisodeIngestionWorker` (Oban) — probe + finalize (§7).

## 12. Operational: directory submission (manual, documented, not built)

After publishing a show, the streamer copies the feed URL and submits it once to each
directory (Apple Podcasts Connect, Spotify for Podcasters, etc.). Provide a short
in-app help section with the feed URL and a "copy" button, plus a docs page. No code
integration with the directories.

## 13. Observability

- Telemetry/PromEx: episodes uploaded, ingestion success/failure, feed fetches,
  downloads per show/episode, storage egress proxy hits.
- Surface per-episode download counts on the streamer's show dashboard.

## 14. Risks & open items

- **Object storage provider + bucket public-access model** — owner provisions; confirm
  public-read vs stable-signed URLs (public-read recommended).
- **Content moderation / DMCA** — feeds are world-readable under our domain. Need a
  takedown path and ToS coverage. Out of v1 code scope but a product/legal must.
- **Storage cost monitoring** — add an alert if egress materially exceeds the ~40 GB/mo
  baseline (guards against a viral episode surprise).
- **VBR parser edge cases** — exotic/corrupt MP3s may defeat the pure-Elixir parser;
  manual duration override is the safety valve (§7).

_Resolved: duration extraction → pure-Elixir parser (§7); website plays count as listens (§9)._

## 15. Implementation phases

1. **Context + storage foundation** — `Podcasts` context, `Show`/`Episode` aggregates,
   migrations, object-storage client + config, presigned upload.
2. **Ingestion** — upload LiveView, `EpisodeIngestionWorker`, MP3 validation + duration.
3. **Public surface** — show/episode pages, in-page player.
4. **RSS feed** — `Services.Feed`, feed controller, caching, validate against Apple's
   feed validator + a real podcast app.
5. **Analytics** — tracking redirect endpoint, `EpisodeDownloaded` events, dashboard.
6. **Polish** — submission help UI, telemetry dashboards, docs page.
