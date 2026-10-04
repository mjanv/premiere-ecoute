# Full application review — 2026-09-27

Reviewed at commit `689060bf`. Eight parallel reviewers each covered one area: core, sessions, external APIs, security, web/LiveView, secondary domains, data layer and quality/ops. A separate skeptic then tried to refute each area's findings against the code. 102 findings were raised. One was refuted, and 4 were duplicates reported by more than one area and have been merged. That leaves **97 findings**: 4 critical, 16 high, 42 medium and 35 low. Each one is marked *confirmed* (the verifier traced the path) or *plausible* (likely, but not proven at runtime). The four critical findings were also checked by hand against the source.

## Overall health

The engineering is disciplined, but the product is not safe to run as it is. The codebase is clean and consistent. It compiles with `--warnings-as-errors`, `credo --strict` is clean, all 2011 tests pass in 24s, and `deps.audit` is clean. It has a coherent in-house CQRS/aggregate framework, Boundary, and Hammox-mocked API behaviours. Domain modelling is mostly sound, with real DB constraints behind the changesets and consistent ownership checks in LiveView mounts. The problems sit at the edges: identity flows, public endpoints, the ops pipeline, and runtime failure semantics. Code style and structure are not where the risk is.

The exposure right now is severe. Four findings allow compromise with no special access:
- **Account takeover:** the Spotify OAuth callback logs in the user named by a client-supplied `state`. I checked `auth_controller.ex:89-95`: `register_spotify_user(auth_data, state)` is followed by `log_in_user`.
- **Admin escalation:** registration casts `role` from client params.
- **OAuth consent bypass:** `GET /oauth/authorize?approved=true` issues a code with no user interaction. Checked: `authorize_controller.ex:21` matches on merged `params`.
- **Public database dumps:** production dumps are uploaded as Actions artifacts, and `gh repo view` reports the repo as `PUBLIC`.

After that come the reliability issues. The session state machine is barely enforced, and Oban jobs are never cancelled. The command, event and event-store writes are not transactional. Report computation is both wrong and expensive. Every push to main goes to prod with no test gate and no migration step.

## Cross-cutting themes

1. **Client input is trusted at the edges.** Several different flows accept client data that should be set server-side:
   - "Spotify OAuth callback trusts `state` as user id"
   - "Registration mass-assigns `role`"
   - "Review edit accepts client-supplied user_id/session_id/role"
   - "Podcast Episode/Show changesets cast ownership and storage fields"
   - "Post-session votes are not validated"
   - "Unauthenticated … upload with path built from attacker-controlled zip metadata"
   - "Twitch OAuth login has no state/CSRF check"
   - "Open redirect in OAuth deny path"

   The root cause is the same everywhere: one broad `changeset/2` serves both internal and user-facing writes, and OAuth state is not signed or bound to the session.

2. **State machines and side effects have no transactional or ordering discipline.**
   - "CommandBus has no transaction boundary"
   - "Store.append always returns :ok, is outside the Repo transaction"
   - "Stop runs Twitch side effects before the state change"
   - "start/1 has no status guard"
   - "EventBus is synchronous… ignores or propagates handler failures"
   - "Complete in collections is neither idempotent nor atomic"
   - "DecideTrack advances current_index without checking…"

   Fallible external calls run before the state change, and failures are swallowed or come back as `{:error, []}`.

3. **Oban scheduling has no uniqueness, cancellation or re-validation.**
   - "Pending auto-advance and open-vote jobs are never cancelled"
   - "Oban uniqueness keys omit user_id"
   - "TrackSpotifyPlayback polling chain has no uniqueness"
   - "Automation 'Run now' … spawns an extra schedule chain"
   - "Oban starts before the caches and GenServers its jobs use"

   Self-rescheduling chains and delayed jobs never check that their premise still holds when they run.

4. **Read-modify-write races and check-then-insert.**
   - "Aggregate.create_if_not_exists is check-then-insert"
   - "Album.create inserts artists outside the album insert"
   - "Billboard submissions stored as a JSONB array and rewritten whole"
   - "Goal balance recomputed … from a transaction snapshot"
   - Report `generate` does get_by and then insert (from "Every page view … rebuilds and rewrites the whole session report")

   The fix is one pattern applied everywhere: upserts with `on_conflict`, `FOR UPDATE`, or normalised tables.

5. **External failures are handled optimistically, often destructively.**
   - "Circuit breaker crashes every Spotify playback poll once a JSON 429 has been cached"
   - "Circuit breaker opens for all users … on a single 503"
   - "Default Req retry sleeps for Spotify's Retry-After with no cap"
   - "A user whose token is revoked crashes their SpotifyPlayer"
   - "TwitchQueue drops messages on send failures"
   - "Enrichment overwrites existing provider IDs with nil on any lookup miss"
   - "LinkProviderTrack stores the first search hit … with no similarity check"
   - "Spotify album and artist-albums fetches ignore pagination"
   - "Events.Store.read silently truncates at 1000 events"

6. **Derived data is computed on read, with the wrong inputs, and without usable indexes.**
   - "Pipelines build reports from a stub session with default 0-10 vote options"
   - "Session averages count missing … scores as 0.0"
   - "SessionLive … writes the report on every mount"
   - "Public billboard dashboard triggers an expensive, un-deduplicated generation"
   - "provider_ids JSONB lookups cannot use the partial unique expression indexes"
   - "ListeningSession.preload/1 … N+1"
   - "Production Repo pool_size of 2"

## Top 10 actions, in priority order

1. **Contain the backup leak today.** Stop the `upload-artifact` step and delete the existing `postgres-backup` artifacts. Then rotate `SECRET_KEY_BASE`, purge `users_tokens` session rows, revoke Boruta tokens and API tokens, and send backups to private, encrypted storage. Also confirm the committed OpenAI key is revoked.
   *Why:* data is exposed right now, so this comes before any code fix.

2. **Fix the identity flows.** Generate a random `state`, bind it to the session and verify it with `secure_compare`, for both Spotify and Twitch. Linking Spotify must take the user from `current_scope` and never call `log_in_user`. Restrict the registration changeset to `:email` and `:username`, and link Twitch identities by Twitch `user_id`, not by email.
   *Why:* two critical account-takeover and admin paths, plus login CSRF.

3. **Harden the OAuth authorization server.** Serve consent on GET only, and read `approved` from `body_params` on POST only. Validate `redirect_uri` against the registered client on deny. Add regression tests for both.
   *Why:* consent bypass and open redirect on an endpoint that issues MCP access.

4. **Close the unauthenticated and public data leaks.** Authenticate or delete `SessionsChannel`, and remove `:email` from User's `json:`. Put the Twitch history upload behind auth, with server-generated UUID paths, UUID-validated route ids, a small size cap and a rate limit.
   *Why:* PII leak and arbitrary file write, both unauthenticated.

5. **Split user-facing changesets from internal ones.** Covers Review, Podcast Episode/Show and `PostSessionVote.submit` (validate against `vote_options` and the session's tracks). Make `Report.to_integer` tolerant of bad values. Add crafted-param LiveView tests.
   *Why:* mass assignment gives a cross-tenant podcast takeover, and one bad vote bricks a report permanently.

6. **Gate deploys.** `release-app.yml` must `needs:` a test and quality job, run `bin/migrate` before restart, and set a `concurrency` group. Move `test/support` out of prod `elixirc_paths`.
   *Why:* today any push to main ships untested code, and schema changes are not applied.

7. **Enforce the session state machine and job hygiene.**
   - Add `status` guards on `start`, `next_track` and `previous_track`, plus a partial unique index on active sessions per user.
   - Put the state transition before Twitch side effects in `stop`.
   - Cancel the session's worker jobs on stop and manual skip.
   - Jobs re-check status and the expected track id.
   - Add `user_id` to the uniqueness keys and stop deduplicating `close`.

   Apply the same uniqueness and re-check pattern to TrackSpotifyPlayback, LinkProviderTrack and automations.

8. **Fix scoring correctness and cost.**
   - Pass the real `vote_options` into the Broadway pipelines.
   - Exclude nil scores from session averages.
   - Branch `!vote` on vote mode.
   - Make read paths read the stored report instead of generating it.
   - Throttle regeneration and use an upsert.
   - Make `polls.track_id` polymorphic (drop the FK).
   - Stop deleting shared `playlists` rows when a session is deleted: that delete currently cascades to other users' sessions, votes and reports.

9. **Fix failure handling in the API layer.**
   - The circuit breaker must store a string reason and open on N failures, not one 503.
   - Cap Req retry and `Retry-After`.
   - Redact token bodies in the `handle/3` rescue.
   - SpotifyPlayer stops normally on a disconnected user.
   - Map Twitch refresh 400 to `:invalid_grant`.
   - Normalise the metric URL tag.
   - Follow pagination on albums and artist albums.
   - TwitchQueue requeues on failure.

10. **Make the core runtime-safe.**
    - Reorder supervision: infra (PubSub, Repo, Vault, EventStore), then domain and caches, then Oban, then Endpoint and MCP.
    - Make `Store.append` return and log errors, and write events in the same transaction (`conn:`) or through an outbox.
    - Give the EventBus one explicit error policy.
    - Use `async_stream_nolink` in Discography.Supervisor.
    - Enrichment only fills nil provider ids and validates name matches with Jaro.
    - JSONB lookups use `@>` or predicate-matching fragments.
    - Make the pool size configurable.

## Notable strengths

- **Tooling:** clean compile, credo strict, dialyzer, doctor and gettext.check in `mix quality`; PR CI with PLT caching; deploy with health check and automatic rollback; Dotenvy `env!` fail-fast config; Cloak-encrypted OAuth tokens.
- **Architecture:** small, readable core (Aggregate macro, declarative `command`/`event` handlers, `Context.impl/0` for Mox), Boundary compiler, and behaviour-driven Hammox mocks with Req.Test.
- **Correct handling of hard problems:** `OauthToken.refresh_locked/4` (`FOR UPDATE` against refresh-token rotation races), Twitch HMAC with `secure_compare` and a replay window, the extension JWT broadcaster check, the image-proxy allowlist, a reasonable CSP, rate-limited login and podcast endpoints, and the Cachex persistence restore race handled through `:cache` provision.
- **Data integrity foundations:** explicit `on_delete` on nearly all FKs, account deletion in a single `Ecto.Multi`, partial unique indexes (wantlist, reviews, `vote_index`), bulk vote inserts with `on_conflict: :nothing`, and identifier-checked raw SQL in Analytics.
- **Web layer:** owner checks in mount, PubSub subscriptions inside `connected?/1`, `assign_async`/`start_async` for slow work, no `raw/1`, consistent use of `<.modal>`, good gettext coverage, and atom conversions on client input that can only crash the one LiveView process, never exhaust atoms.

The coverage gaps set how much to trust these results: 24 of 96 LiveViews have tests, `lib/premiere_ecoute_web` is excluded from coverage, and the Broadway tests rely on sleeps.

## Area summaries

### core

The core layer (lib/premiere_ecoute_core) is a small in-house framework. It has a synchronous CQRS-style CommandBus and EventBus with handlers resolved through :persistent_term, an Ecto `Aggregate` macro that generates CRUD, pagination and stats, an EventStore wrapper (PremiereEcoute.Events.Store) used as an append-only audit log, a Cachex wrapper with disk persistence, an Oban `Worker` macro, a Req-based `Api` macro with a circuit breaker, and a supervisor macro that every domain uses. Strengths: the pieces are small and readable. Handler registration is declarative (`command`/`event` macros). `Context.impl/0` makes contexts swappable for Mox. The PersistenceHook handles the Cachex restore race correctly by using the `:cache` provision. Boundary is enabled as a compiler. The main weaknesses are in how the system behaves at runtime rather than in code style:
- **Supervision order is wrong.** The web Endpoint starts before Repo and Oban, and Oban starts before the caches and GenServers its jobs depend on.
- **Commands have no transaction boundary.** A command can commit database state and then return `{:error, []}` without emitting its events.
- **The event store ignores failures.** `Store.append` always returns `:ok` and is never part of the Repo transaction.
- **Event dispatch is synchronous with one handler per event.** Handler errors are silently ignored or crash the caller.
- **Some core pieces are dead or broken.** A subscriber is never started, and there is a debug module, a broken macro and a compile-time git call.
- **Boundary does not protect the core.** `PremiereEcouteCore` declares `deps: []` but depends on the `PremiereEcoute` domain in several places, and Boundary cannot see references made through macros.

### sessions

The listening-sessions domain runs a command/event pipeline: commands such as Prepare/Start/Skip/Stop go to CommandHandler, which emits events. EventHandler then schedules Oban jobs in ListeningSessionWorker, and those jobs open and close vote windows by writing a per-broadcaster Cachex entry. Two Broadway pipelines read that cache to record chat votes and Twitch polls, and recompute the Report on each batch. Collections (playlist triage) follows the same pattern. Strengths: the command/event split is clean. Spotify playback failures are reported without blocking the command (the `playback_outcome` folding). Votes have a real DB unique index (`vote_index`), and the web layer does check that the session belongs to the user before issuing commands. Weaknesses: (1) The session state machine is enforced almost nowhere. Only `stop/1` checks status. `start/1` and `next_track/1` accept any state, and irreversible Twitch side effects run before the state change. (2) Scheduled Oban jobs are never cancelled and never re-check session state, so auto-advance and open-vote jobs fire after a manual skip or after stop. (3) Scoring has correctness gaps: the live pipelines always use numeric mode, missing scores default to 0.0 and pull session averages down, and post-session votes are not validated. One malformed post-session vote makes the session's Report crash on every rebuild. (4) The worker's uniqueness keys omit `user_id`, so jobs for different streamers deduplicate each other.

### apis

This area covers the outbound HTTP clients: Spotify (catalog, player, playlists, OAuth), Twitch (OAuth, chat via TwitchQueue, EventSub, polls, rewards), Deezer, Tidal, YouTube, Genius, MusicBrainz, Wikipedia, Discord, BMAC and Frankfurter. All of them are built on the `PremiereEcouteCore.Api` macro, which wraps Req and adds config, telemetry, a `handle/3` status and parse wrapper, and client-credentials token caching. Next to them sit the Mistral/Whisper model wrappers, the SpotifyPlayer poller and a dev-only Twitch mock server (started only when `:environment == :dev`).

The design is consistent and has real strengths. Behaviours sit behind `Apis.provider/1` and are mocked with Hammox. `OauthToken.refresh_locked/4` serializes token refresh with `SELECT ... FOR UPDATE`, which closes the concurrent refresh-token-rotation race. Spotify `invalid_grant` is mapped to disconnecting the provider. The Twitch HMAC check uses `secure_compare` and a timestamp freshness window. Playlist pagination is bounded (`async_stream`, `max_concurrency: 5`) and write chunking respects Spotify's 100-item limit. SpotifyPlayer backs off exponentially and has a poll budget. TwitchQueue enforces the Twitch chat limits locally with Hammer.

The weak spots are in failure handling:
- The only circuit breaker crashes as soon as it trips on a JSON 429.
- Req's default retry honors unbounded `Retry-After` values on every catalog GET.
- `handle/3`'s rescue logs whole OAuth token response bodies.
- A disconnected user raises inside the shared player supervisor tree.
- Twitch refresh failures are never classified as revoked.
- Several paging endpoints (album tracks, artist albums) silently truncate.
- Metrics use raw URL paths as a tag.
- EventSub has no message-id dedup.

### security

This area covers authentication (phx.gen.auth session tokens, magic links, Twitch/Spotify OAuth via hand-rolled flows), role-based LiveView authorization (on_mount :viewer/:streamer/:admin), admin impersonation, a REST API authenticated by long-lived Bearer tokens, a Boruta OAuth 2.1 authorization server with dynamic client registration in front of the Hermes MCP endpoint, webhooks (Twitch EventSub, Buy Me a Coffee, Twilio), and public endpoints such as the image proxy, podcasts, viewer submissions and the Twitch history upload. Several things are done well. Twitch EventSub HMAC uses secure_compare and a replay window. The extension JWT is checked against the broadcaster id. The image proxy has a host allowlist. The CSP sets object-src, base-uri, form-action and frame-ancestors. Login and podcast endpoints are rate limited. Ownership checks in LiveView mounts are consistent: billboards, podcast studio, collections, session dashboard, automations and MCP tools all scope by current user. The Boruta DCR controller also deliberately avoids the over-privileged-client issue. The weak spot is the edges of the identity flows. The Spotify OAuth callback trusts a client-controlled `state` as the user id and logs that user in, which allows full account takeover of any user including admins. Registration casts `role` from client params, which lets an attacker escalate to admin through the Twitch email-matching login. The OAuth authorize endpoint accepts `approved=true` over GET, so the consent screen can be skipped. An unauthenticated Phoenix channel leaks every active streamer's email. These need fixing before anything else.

### web

The UI layer is 96 LiveViews plus about 22k lines of components. The basics are mostly sound. Owner checks are done in mount for the streamer pages (DashboardLive, CollectionSessionLive, Billboards.ShowLive, Podcasts studio, PlaylistLive). PubSub subscriptions are almost always inside `connected?/1`. `assign_async`/`start_async` are used for slow work. The `<.modal>` component is used throughout: the only raw `fixed inset-0` shells are inside the component library itself. There is no `raw/1` HTML injection, and gettext coverage in templates is good. Atom handling is safe: every `String.to_existing_atom` on client input can only crash the one LiveView process, never exhaust atoms. The main problems are trust boundaries on public or low-privilege pages. First, the unauthenticated Twitch history upload writes to a disk path taken from inside the zip. Second, review forms pass client params straight into a changeset that casts `user_id`, `session_id` and `role`. Third, post-session votes are inserted with no validation, so one crafted vote can permanently break a session's report. There are also secondary issues: DB-writing work (`Report.generate`) runs on every public page view and on both the dead and connected mounts, SessionLive skips the visibility check, the overlay never re-joins Presence after its first session ends, `Repo` is called directly from LiveViews, and only 24 of 96 LiveViews have tests.

### domains

Scope: discography (albums, singles, artists, tracks, enrichment pipeline), radio (Spotify polling, provider linking, retention), wantlists, playlists (library playlists, subscriptions, submissions, automations), podcasts, donations, notifications, billboards, twitch (history and rewards), and the events store. The code is well organised. Contexts delegate cleanly to aggregates, most schemas pair changesets with real DB constraints (partial unique indexes per provider, FK constraints, unique wantlist indexes), and several spots are careful: `Ecto.Map` uses `String.to_existing_atom`, `Submission.delete_stale` guards against an empty `NOT IN` list, automations record step failures without retrying destructive steps, and podcast ingestion keeps the object store private. The weak spots are:
- Two security holes. Unauthenticated Twitch history uploads build file paths from user-controlled data, and the podcast changesets let a streamer mass-assign ownership and storage-key fields.
- An enrichment pipeline that overwrites good provider IDs with nil or with name-search guesses.
- JSONB provider lookups that cannot use the unique indexes built for them. `EXPLAIN` on the dev DB confirms a sequential scan.
- Oban jobs that reschedule themselves or run on a schedule, with no uniqueness, so repeated triggers create duplicate job chains.
- Read-modify-write races on JSONB arrays and cached balances.
- Event-store reads that silently stop at 1000 events.

### data

The data layer is Postgres through Ecto. Most schemas use the `PremiereEcouteCore.Aggregate` macro, which gives them CRUD, preload and paging functions. Votes and polls come in through two Broadway pipelines, and reports are stored as denormalized JSON on `reports`. The groundwork is mostly solid. Nearly every foreign key sets an explicit `on_delete`, so account deletion cascades cleanly; I checked the multi-path cascade on the dev Postgres and it works. There are partial unique indexes for wantlist items, playlist rules and reviews. Account deletion runs as a single `Ecto.Multi`. Chat votes are written in bulk with `insert_all ... on_conflict: :nothing`. History and home-page queries mostly carry `limit`s. The raw SQL in `Analytics.Events` checks its identifiers before building the query. The main problems are in three places. (1) Reports are computed in a way that is both wrong and expensive: the pipelines pass a stub session with default vote options, and every page view and every batch of 5 votes reloads all of the session's votes. (2) Two foreign keys don't fit how the rows are shared: `playlists` rows are shared between users, and `polls.track_id` points only at `album_tracks` but also receives single IDs. (3) Some indexes are missing or can't be used, most importantly the JSONB `provider_ids` lookups, which the planner can never serve from the partial unique indexes. I confirmed that last point with EXPLAIN on the dev DB. Migrations look fine for this data size: tables are small (dev has about 70 albums, about 900 tracks and 157 votes), and no migration rewrites a large table.

### quality

This area covers tests, tooling, config and ops. Test suite: 2011 tests pass and 11 are excluded, in 24.2s (11.3s async, 12.8s sync), against the local Postgres 18.4 container. The toolchain is in good shape. `mix compile --warnings-as-errors` passes (exit 0; the only warnings are in dependencies: sentry type warnings, ueberauth_twitch/ueberauth_spotify unused code). `mix credo --strict` reports no issues (899 files, 5163 mods/funs). `mix deps.audit` finds no vulnerabilities. `mix hex.outdated` exits 1, but the only update possible is bumblebee 0.7.1 -> 0.8.0; nx/exla 1.0.0 are blocked by requirements, and everything else is up to date. `mix sobelow --exit low` exits 1 with 38 findings. 24 are low-confidence Traversal/SendFile hits and 3 are missing-CSP hits on the browser/podcast_public/app pipelines (likely false positives, since the app uses plug_content_security_policy). The one that matters is the high-confidence CSRFRoute on /oauth/authorize, confirmed below. Strengths: Mox/Hammox behaviour-driven API mocks with Req.Test plugs, a Boundary compiler, a strict `mix quality` alias (dialyzer, doctor, gettext.check), a PR CI with PLT caching, a release deploy with health check and automatic rollback, runtime secrets loaded through Dotenvy `env!` (missing vars fail fast), and Cloak-encrypted OAuth tokens. The biggest problems are operational. Daily production DB dumps are uploaded as Actions artifacts on a public repo. Pushes to main deploy straight to prod with no test gate and no migration step. The OAuth authorize endpoint mints codes on GET.

## Findings

### Critical (4)

#### 1. Production database dumps are uploaded as GitHub Actions artifacts on a PUBLIC repository

`.github/workflows/backup-db.yml:43` · quality · security · confirmed

**Evidence.** `ssh root@... "sudo -u postgres pg_dump -Fc premiere_ecoute_prod > /tmp/${DUMP_NAME}"` then `uses: actions/upload-artifact@v4 with: name: postgres-backup path: ${{ steps.dump.outputs.dump_name }} retention-days: 2`. `gh repo view --json visibility` returns `PUBLIC`. On public repos, workflow run pages and their artifacts can be downloaded by anyone with read access, which here means any signed-in GitHub user. The dump is unencrypted. Session tokens are stored raw: `build_session_token` puts `token: token` into users_tokens (lib/premiere_ecoute/accounts/user/token.ex:73). Boruta access tokens are stored in oauth_tokens.

**Failure scenario.** Any GitHub user opens the Actions tab of mjanv/premiere-ecoute, downloads today's `postgres-backup` artifact, and restores it. They get every user's email and profile, raw session tokens (valid for the session-validity window, so they can hijack any logged-in account including admins), MCP/OAuth bearer tokens, and all app data. Only the Cloak-encrypted columns stay protected. This recurs every day at 03:00 UTC.

**Fix.** Stop uploading dumps as artifacts right away. Delete the existing `postgres-backup` artifacts and rotate SECRET_KEY_BASE, which invalidates the signed session cookies that wrap the tokens. Also delete all rows in users_tokens with context 'session' and revoke the Boruta tokens. Ship backups to private object storage (for example DO Spaces/S3 with a bucket policy), encrypted with `age`/`gpg` before they leave the droplet. Keep more than one generation: the job currently deletes every older artifact, so only one 2-day copy ever exists.

#### 2. [FIXED] Spotify OAuth callback trusts `state` as user id and logs that user in: account takeover of any account (incl. admin)

`lib/premiere_ecoute_web/controllers/accounts/auth_controller.ex:89` · security · security · confirmed

**Evidence.** request/2 builds `SpotifyApi.authorization_url(nil, to_string(id))` (line 48), so `state` is the plain user id. callback/2: `with {:ok, auth_data} <- SpotifyApi.authorization_code(code, state), {:ok, user} <- AccountRegistration.register_spotify_user(auth_data, state) do conn |> ... |> UserAuth.log_in_user(user, %{})`. `SpotifyApi.Accounts.authorization_code(code, _state)` ignores state, and `register_spotify_user(payload, id)` does `Accounts.get_user!(id)` and attaches the tokens. `state` is never bound to the browser session.

**Failure scenario.** The attacker authorizes the app with their own Spotify account (the /auth/spotify URL is public, and only client_id/redirect_uri are needed). They intercept the redirect and replay `/auth/spotify/callback?code=<their code>&state=1`, or whatever the admin's id is (ids are sequential integers). The server exchanges the valid code, loads user 1, attaches the attacker's Spotify tokens, and calls `log_in_user(user 1)`. The attacker now holds an admin session, with no prior account and no interaction from the victim.

**Fix.** Generate a random `state`, store it in the session (or a signed short-lived cookie) together with the initiating user's id, and verify it in the callback with `Plug.Crypto.secure_compare`. Take the user from `conn.assigns.current_scope.user`, never from `state`. Linking Spotify should never call `log_in_user`; require an existing authenticated session and just redirect back.

#### 3. [FIXED] OAuth consent bypass: GET /oauth/authorize?approved=true issues a code without user interaction

`lib/premiere_ecoute_web/controllers/oauth/authorize_controller.ex:21` · security, quality · security · confirmed

**Evidence.** `def authorize(%Plug.Conn{params: %{"approved" => "true"}} = conn, _params), do: Boruta.Oauth.authorize(resource_owner(conn), __MODULE__)`. The router mounts it on both `get "/authorize"` and `post "/authorize"` (router.ex:462-463), and `conn.params` includes query params. CSRF protection only applies to POST, and the session cookie is SameSite=Lax, so it is sent on top-level GET navigations.

**Failure scenario.** The attacker self-registers a public client through open DCR (`POST /oauth/register`, token_endpoint_auth_method none, redirect_uris [https://attacker/cb]). They get a logged-in victim to open `https://premiere-ecoute.fr/oauth/authorize?approved=true&response_type=code&client_id=<id>&redirect_uri=https://attacker/cb&code_challenge=<their S256>&code_challenge_method=S256&scope=mcp`. Boruta mints a code and redirects it to the attacker, who redeems it with their verifier. The result is an MCP access token acting as the victim (profile, sessions, wantlist add/remove, radio save).

**Fix.** Only honour `approved` on POST: pattern-match `%Plug.Conn{method: "POST", body_params: %{"approved" => ...}}` and read it from body_params, not merged params. Route GET to preauthorize/consent only. Also consider rate-limiting DCR and showing the redirect_uri host on the consent screen, because the client name is attacker-controlled.

#### 4. [FIXED] Registration mass-assigns `role`; combined with Twitch email-matching login this gives admin

`lib/premiere_ecoute_web/live/accounts/user_registration_live.ex:34` · security · security · confirmed

**Evidence.** `handle_event("save", %{"user" => user_params}, socket)` calls `Accounts.User.create(user_params)`, which runs `User.changeset/3`: `cast(attrs, [:email, :username, :role]) |> validate_inclusion(:role, [:viewer, :streamer, :admin, :bot])` (user.ex:59). No email confirmation is needed to create the row. In AuthController.callback for Twitch, `User.get_user_by_email(auth_data.email)` finds an existing user and `register_twitch_user` only refreshes tokens on it (it never recomputes role), then calls `log_in_user(user)`.

**Failure scenario.** The attacker sends a LiveView `save` event with `{"user": {"email": "me@attacker.tld", "role": "admin"}}` on /users/register. The user row is created with role admin. The attacker then signs in with a Twitch account whose email is me@attacker.tld. The callback matches the email, attaches Twitch tokens to the pre-created admin row and logs them in. They now have /admin, /oban, impersonation and role changes. The same pre-registration trick also lets an attacker squat a victim's email before the victim's first Twitch login (pre-account-takeover).

**Fix.** Use a registration changeset that casts only `:email` (and `:username`) and never `:role`. Keep role assignment in `AccountRegistration.role/1` and admin tooling only. Also consider refusing to merge a Twitch identity into an existing account that was never confirmed or never linked to that Twitch user_id. Link by Twitch `user_id`, not by email.

### High (16)

#### 5. [FIXED] OAuth token responses (access and refresh tokens) are written to error logs

`lib/premiere_ecoute/apis/music_provider/spotify_api/accounts.ex:67` · apis · security · confirmed

**Evidence.** `authorization_code/2` runs `{:ok, user} = SpotifyApi.get_user_profile(body["access_token"])` inside the `handle/3` callback. `handle/3` (core/api.ex:98-103) rescues any exception and logs `"#{name} API unexpected body: #{status} - #{inspect(body)}"`, where `body` is the full `/api/token` response. Twitch has the same pattern (twitch_api/accounts.ex:80 `{:ok, user} = TwitchApi.get_user_profile(...)` and the `%{"token_type" => "bearer"}` match). Twitch `renew_token` (accounts.ex:108) crashes the clause when the response has no `refresh_token`, which is also rescued and logged with the body.

**Failure scenario.** A Spotify user who is not on the development-mode allowlist completes OAuth. `/v1/me` returns 403, `get_user_profile` returns `{:error, _}`, and the match raises `MatchError`. `handle/3` then logs, at error level, a line containing that user's `access_token` and long-lived `refresh_token`. Log shipping and Sentry's Logger integration pick it up. Anyone with log access can control that user's Spotify (playback, playlists) until they revoke it.

**Fix.** Do the profile fetch in a `with` outside `handle/3` and return `{:error, reason}` explicitly. In `handle/3`'s rescue, log the exception and the status, not the raw body. Or redact known secret keys (`access_token`, `refresh_token`, `id_token`) before calling `inspect`.

#### 6. A user whose token is revoked crashes their SpotifyPlayer and can take down all players

`lib/premiere_ecoute/apis/players/spotify_player.ex:66` · apis · correctness · confirmed

**Evidence.** On `invalid_grant`, `OauthToken.refresh_locked/4` disconnects Spotify and `maybe_renew_token` returns a scope with `user.spotify == nil`. The poll then calls `Apis.spotify().get_playback_state(scope, old_state)`, which reaches `SpotifyApi.api(%Scope{})`, and that clause does `raise(NotConnectedError)` (spotify_api.ex:137). The `with` only handles `{:error, reason}`, so the GenServer crashes. It is `restart: :transient`, so it restarts, and `init/1` calls `get_playback_state` again and raises again.

**Failure scenario.** During a stream, one streamer's Spotify refresh token is revoked (password change or app removed). Their player crashes, restarts, and crashes again in `init`. The shared `PlayerSupervisor` (default intensity 3 restarts in 5 s) exits, and every other streamer's playback poller is killed and not restarted, because dynamic children are lost when the supervisor restarts.

**Fix.** In SpotifyPlayer, match on a missing `scope.user.spotify` and stop with `{:stop, :normal, ...}` after publishing a `:disconnected` event. Have the Player functions return `{:error, :not_connected}` instead of raising, or rescue `NotConnectedError` in the player. Consider `restart: :temporary` for pollers.

#### 7. Circuit breaker crashes every Spotify playback poll once a JSON 429 has been cached

`lib/premiere_ecoute_core/api/circuit_breaker.ex:25` · apis · correctness · confirmed

**Evidence.** `maybe_open` stores the decoded response body: `Cache.put(@cache, opts[:api], response.body, expire: retry_after * 1_000)` (line 34). `maybe_halt` then builds `Req.Request.halt(request, RuntimeError.exception(reason))`. Spotify 429 bodies are JSON, and Req's `decode_body` step runs before the appended `circuit_breaker` response step, so `reason` is a map. `RuntimeError.exception/1` only accepts a binary or a keyword list. Verified: `RuntimeError.exception(%{"a" => 1})` raises `FunctionClauseError`. Req does not rescue exceptions raised by request steps. The only user is `Player.get_playback_state/2` (player.ex:207), and `test/premiere_ecoute_core/api/circuit_breaker_test.exs` only covers `retry_after_seconds/1`, not the halt path.

**Failure scenario.** Spotify answers `/me/player` with 429 and a body like `{"error":{"status":429,...}}`. For the whole Retry-After window, the cache key `:spotify` holds a map. Every `SpotifyPlayer` `:poll`, and every `init/1` on restart, raises `FunctionClauseError` instead of getting `{:error, _}`. All players of all users crash-loop at the same moment and exceed the `PlayerSupervisor` restart intensity, so the DynamicSupervisor restarts with no children. Overlays stop until a user reconnects. The designed back-off never engages.

**Fix.** Store a string reason, e.g. `"rate limited (429)"`, or halt with a dedicated exception struct that carries the body, for example `defexception [:api, :body]`. Add a test that sets up a 429 with a JSON body and asserts that the next call returns `{:error, _}`.

#### 8. Deleting one session deletes a shared Playlist row, which cascades to other sessions and their votes and reports

`lib/premiere_ecoute_web/live/sessions/sessions_live.ex:69` · data · correctness · confirmed

**Evidence.** `if deleted_session.playlist do Playlist.delete(deleted_session.playlist) end`. `playlists` is a shared catalog table (unique on `[:playlist_id, :provider]`, and `get_or_create_playlist/1` in command_handler.ex:686 reuses an existing row). The FK is `add :playlist_id, references(:playlists, on_delete: :delete_all)` (priv/repo/migrations/20250902123714_allow_playlist_listening_session.exs:12). The session delete and the playlist delete are not in one transaction, and the result of `Playlist.delete` is ignored.

**Failure scenario.** Streamer A and streamer B both run a session on the same Spotify playlist, so both sessions point to the same `playlists` row. A deletes their own session. `Playlist.delete` removes the shared row, and Postgres cascades the delete to B's listening_session, then to B's votes, polls, reports, track_markers and notes. B loses the session without warning. If B's session still has `current_playlist_track_id` set (an ON DELETE RESTRICT FK), the delete raises instead, and the failure is silently ignored.

**Fix.** Stop deleting the catalog row when a session is deleted. Treat `playlists` like `albums`: change the FK to `on_delete: :restrict` or `:nothing`, and if orphaned playlists need cleanup, do it in a periodic job that deletes playlists no session references. Put any remaining multi-step delete in one `Ecto.Multi`.

#### 9. polls.track_id has an FK to album_tracks, but free-mode poll sessions store a singles.id in it

`priv/repo/migrations/20250629123456_create_scores.exs:13` · data · correctness · confirmed

**Evidence.** `add :track_id, references(:album_tracks, on_delete: :delete_all), null: false`. In free mode, `%VoteWindowOpened{track_id: session.single_id, ...}` (command_handler.ex:639) leads to `open_free_poll`, which caches `current_track_id: track_id` (listening_session_worker.ex:255). PollPipeline then builds `%Poll{track_id: track_id}` from that cache (poll_pipeline.ex:57), and `Poll.changeset` declares `foreign_key_constraint(:track_id)`. `votes.track_id` has no FK and is used polymorphically, but `polls.track_id` is not.

**Failure scenario.** A free-mode session with 5 or fewer vote options has vote_mode `:poll`. When a Twitch poll starts, `Poll.create` either fails the FK check (the poll is logged as 'Failed to upsert', and later PollUpdated events hit `:skip` because no row exists), or it silently attaches the poll to an unrelated `album_tracks` row whose id happens to equal the single's id. Both ID spaces are small integers, so collisions are likely. Either way, free-mode poll results never reach the report. The dev DB has 2 free/poll sessions and 0 polls rows.

**Fix.** Make `polls.track_id` polymorphic like `votes.track_id`: drop the FK, or add a nullable `single_id`/`track_type` column. Otherwise keep separate FKs per source. Add an integration test that runs PollStarted and PollUpdated for a free-mode session.

#### 10. Album/Artist enrichment overwrites existing provider IDs with nil on any lookup miss or transient API error, and with unvalidated name-search guesses

`lib/premiere_ecoute/discography/services/enrich_album.ex:30` · domains · correctness · confirmed

**Evidence.** `provider_ids = [:spotify, :deezer, :tidal] |> Supervisor.async(fn k -> {k, enrich(k, album)} end) |> Enum.into(%{}) |> then(&Map.merge(album.provider_ids, &1))`. Every `enrich/2` clause maps `{:error, _reason} -> nil`, and the spotify clause returns nil unless a result name matches `String.downcase` exactly. Because `Ecto.Map` atomizes keys, `%{spotify: nil}` replaces the stored `:spotify` id. EnrichArtist (enrich_artist.ex:113-117) does the same for `[:spotify, :deezer, :tidal, :youtube_music]`, taking the first `search_artist(name)` hit with no similarity check. The module docs claim "stored only if the key is not already present... skipped without making an API call", which the code does not do.

**Failure scenario.** Spotify rate-limits or 5xxs while EnrichAlbumWorker runs, or the album title differs in punctuation ("Vol. 1" vs "Vol 1"). The album's Spotify id becomes null. `find_by_provider(id, :spotify)`, `create_if_not_exists`, playback (`start_resume_playback`) and wantlist matching (`wantlisted_spotify_ids`) all stop finding it, and the next sync creates a duplicate album. Because the key now exists with a null value, `Album.random/0` (`NOT (provider_ids ? 'spotify')`) never selects it for repair. For artists, EnrichDiscographyWorker creates an artist from an exact Spotify id and immediately enqueues EnrichArtistWorker, which replaces it with the top name-search hit. For homonyms (e.g. two bands called "Nirvana") the artist is silently re-pointed and later discography syncs pull the wrong albums.

**Fix.** Only fill keys that are absent or nil, and never overwrite a non-nil id with nil. Distinguish `{:error, _}` (skip, keep the old value, maybe retry) from `{:ok, []}` (record "not found"). Keep ids that came from the provider itself (Spotify id from the Spotify API) as authoritative. Validate name-search hits with the existing Jaro filter (`PremiereEcouteCore.Search.filter`) on both artist and title. Fix the moduledocs to match.

#### 11. Podcast Episode/Show changesets cast ownership and storage fields; edit forms pass raw params, allowing cross-tenant takeover and deletion of other streamers' audio

`lib/premiere_ecoute/podcasts/episode.ex:127` · domains · security · confirmed

**Evidence.** `cast(attrs, [:guid, :title, :description, :audio_key, :audio_byte_size, :duration_seconds, :season, :episode_number, :episode_type, :status, :published_at, :show_id])`. Show.changeset (show.ex:75) casts `:cover_key, :published, :user_id`. EpisodeFormLive `save` for :edit calls `Podcasts.update_episode(episode, params)` with the unfiltered form map, and ShowFormLive :edit calls `Podcasts.update_show(show, params)`. `Podcasts.delete_episode/1` deletes `Storage.delete(key)` for whatever `audio_key` the row holds, and `delete_show/1` does the same with `cover_key`. The moduledoc says guid/audio_key are "write-once", but nothing enforces it.

**Failure scenario.** A streamer edits their own episode and adds hidden form fields: `episode[audio_key]=podcasts/42/episodes/<victim-guid>.mp3`, then deletes the episode. `Storage.delete` removes the victim's MP3 from the object store. Other variants: `episode[show_id]=<victim show id>` injects an episode into another streamer's public RSS feed, `episode[status]=ready` skips ingestion validation, and `show[user_id]=<other user>` reassigns show ownership. The same trick with `show[cover_key]` plus deleting the show removes another show's cover.

**Fix.** Split changesets. Use a user-facing `metadata_changeset` that casts only title/description/season/episode_number/episode_type (and title/description/author/language/category/explicit/published for shows). Keep internal `ingest_changeset`/`create_changeset` for server-set fields, and make guid/audio_key/show_id/user_id immutable after insert. Alternatively, `Map.take` allowed keys in the context functions rather than the LiveView.

#### 12. Unauthenticated Twitch history upload/view builds filesystem paths from user-controlled RequestID / URL id (path traversal, arbitrary .zip write/read)

`lib/premiere_ecoute/twitch/history.ex:19` · domains · security · confirmed

**Evidence.** `def file_path(id), do: Path.join([PremiereEcoute.uploads_dir(), "#{id}.zip"])`. `id` is `RequestID` read from `request/metadata.json` inside the uploaded zip (history_live.ex: `File.cp!(path, History.file_path(request_id))`) or the `:id` URL segment (history_view_live.ex: `file_path = History.file_path(id)`). The routes `/twitch/history` and `/twitch/history/:id` sit in a live_session with only `{UserAuth, :current_scope}`, so they need no login. `Path.join` does not normalise `..`.

**Failure scenario.** An anonymous user uploads a zip whose metadata.json contains `"RequestID": "../../../../tmp/x"` (or a path into priv/static). The app then `File.cp!`s attacker bytes to `<uploads>/../../../../tmp/x.zip`, which writes or overwrites any `*.zip` the BEAM user can write. A victim's RequestID can also be reused to overwrite their stored history. On the read side, `/twitch/history/..%2F..%2Fsomething` makes the async readers open arbitrary `.zip` files. Uploads of up to 999 MB are accepted anonymously and never cleaned up, so disk exhaustion is also trivial. The files are personal Twitch exports (chat logs, watch history) readable by anyone who has the id.

**Fix.** Never derive paths from archive content. Generate a server-side id (UUID) for the stored file and validate any `id` from the URL against `^[0-9a-f-]{36}$` before `Path.join`. Require authentication, and store files under the owner's user id with an ownership check on view. Add a retention/cleanup job and a much lower size limit.

#### 13. [REJECTED] Every push to main deploys to production without running tests or quality checks

`.github/workflows/release-app.yml:3` · quality · ops · confirmed

**Evidence.** `on: push: branches: - main` with a single job `build-and-deploy` and no `needs:` on any test job. pr-app.yml only runs on `pull_request`. The recent history (`689060bf erlang 29.1.1 / deps`, `d5816894 fix(ui)...`, `58a2c547 ci`) shows direct commits to main. There is also no `concurrency:` group, so two quick pushes run two deploys in parallel. Both do `rm -rf /opt/premiere-ecoute-backup; cp -a ...` and rsync into the same directory.

**Failure scenario.** A commit that compiles but breaks behaviour (a `deps` bump, for example) is pushed to main. The release is built and rsync'ed without `mix test` ever running. The /health check only confirms the endpoint boots, so the regression goes live. With two overlapping pushes, deploy A's rollback can restore deploy B's backup, or a backup taken mid-rsync.

**Fix.** Add a test job to release-app.yml, or trigger it on `workflow_run` of a CI workflow that also runs on push to main. Make the deploy `needs: [tests]`. Add `concurrency: { group: deploy-prod, cancel-in-progress: false }`.

#### 14. Unauthenticated Phoenix channel dumps all active sessions, including streamer emails

`lib/premiere_ecoute_web/channels/sessions_channel.ex:20` · security · security · confirmed

**Evidence.** UserSocket `connect(_params, socket, _connect_info)` accepts every connection (user_socket.ex:28). `handle_in("get_sessions", ...)` does `ListeningSession.all(where: [status: :active]) |> Enum.map(&Jason.encode!/1)`. ListeningSession JSON includes `:user` (preloaded with twitch/spotify), and User JSON is `json: [:id, :email, :role, :twitch, :spotify]`, with OauthToken exposing `[:user_id, :username]`.

**Failure scenario.** Anyone opens a websocket to wss://premiere-ecoute.fr/socket/websocket, joins `sessions:lobby`, and pushes `get_sessions`. They receive the email address, role, Twitch and Spotify ids of every streamer currently live, regardless of the session's `visibility: :private`. This is a PII/GDPR leak and enables targeted phishing. `session:<id>` also lets anyone read any session's report by sequential id.

**Fix.** Authenticate the socket (a Phoenix.Token signed with the user id and verified in connect/3), or remove this legacy channel if it is unused. Never JSON-encode `User` with `:email`: drop email from the User `json:` list and return an explicit, minimal DTO filtered by visibility.

#### 15. Unauthenticated 999 MB upload with path built from attacker-controlled zip metadata

`lib/premiere_ecoute_web/live/twitch/history_live.ex:39` · security, web · security · confirmed

**Evidence.** The route `/twitch/history` sits in live_session :twitch with only `:current_scope`, and the moduledoc says 'This is an unauthenticated page'. `allow_upload(:request, accept: ~w(.zip), max_file_size: 999_000_000, max_entries: 1)`, then `%History{request_id: request_id} -> File.cp!(path, History.file_path(request_id))`. history.ex:19: `def file_path(id), do: Path.join([PremiereEcoute.uploads_dir(), "#{id}.zip"])`. `request_id` comes from `RequestID` in the uploaded zip's metadata.json. The view route `/twitch/history/:id` then reads any `<id>.zip`, also without auth.

**Failure scenario.** (1) Disk exhaustion: anonymous clients upload ~1 GB zips repeatedly, with no rate limit and no cleanup. (2) Path traversal and overwrite: a zip with `RequestID: "../../some/dir/name"` is copied outside uploads_dir, and setting another user's RequestID overwrites their export. (3) Privacy: anyone who knows or guesses a request id can view another person's Twitch data export (chat messages, subscriptions, bits) at /twitch/history/<id>. Zip parsing of untrusted archives also risks zip-bomb memory blowups.

**Fix.** Require authentication and store uploads under a server-generated UUID tied to the uploading user, not the zip's RequestID. Validate any id with a strict regex (e.g. UUID) before Path.join. Enforce ownership on the view routes, add a much smaller size limit plus a rate limit, and add a retention/cleanup job.

#### 16. Pending auto-advance and open-vote jobs are never cancelled and do not check session state

`lib/premiere_ecoute/sessions/listening_session/listening_session_worker.ex:168` · sessions · correctness · confirmed

**Evidence.** The `next_track` job calls `PremiereEcoute.apply(%SkipNextTrackListeningSession{source: :album, ...})` without checking status. `ListeningSession.next_track/1` (listening_session.ex:359) has no status guard, and on `current_track: nil` it picks `hd(tracks)`. `stop/1` sets `current_track_id` to nil. `open_album`/`open_playlist` (lines 76 and 102) also never check `session.status`. `ListeningSessionWorker.cancel_all` is never called anywhere in lib/ (grep finds cancel_all only in radio).

**Failure scenario.** Auto-next is set to 10s. The last album track ends, and the dashboard schedules `next_track` for +10s (dashboard_live.ex:582). The streamer clicks Stop at +5s. At +10s the job advances the stopped session from nil to track 1: Spotify starts playing track 1, chat gets "[1/12] ...", a TrackMarker is added to the stopped session, and `open_album` later posts "Votes are open !" after "The premiere is over". A second case: the streamer skips manually while an auto-advance job is pending, and the job then skips a second track.

**Fix.** Cancel the session's pending ListeningSessionWorker jobs (by session_id) on SessionStopped and on every manual skip. In addition, make each job re-check `session.status == :active`, and for next_track also check the expected current track id (put it in the job args), and exit as a no-op otherwise. Add `%{status: :active}` guards to `next_track/1` and `previous_track/1`.

#### 17. Live vote and poll pipelines always build the report in numeric mode and crash for smash/pass sessions

`lib/premiere_ecoute/sessions/scores/message_pipeline.ex:89` · sessions, data · correctness · confirmed

**Evidence.** `{:ok, report} = Report.generate(%ListeningSession{id: session_id})` passes a bare struct, so `vote_options` is the schema default `["0".."10"]` and `vote_mode/1` returns `:numeric`. For a smash-pass session, `calculate_average_score(votes, :numeric)` calls `String.to_integer("smash")` and raises. poll_pipeline.ex:89 has the same bug, and there `extract_poll_score(..., :numeric)` does `String.to_integer(option)`.

**Failure scenario.** A streamer runs a smash-pass album session. Every chat vote batch inserts its votes, then `handle_batch` raises ArgumentError. The overlay and dashboard never get a `{:session_summary, ...}` update, and Broadway logs failures for every batch. In free mode, smash-pass has 2 options, so `vote_mode` is `:poll`, and every PollUpdated batch also crashes. The poll row is saved, but no summary is broadcast.

**Fix.** Load the session's vote_options before generating, e.g. `Report.generate(ListeningSession.get(session_id))` or a light query selecting `vote_options`. Alternatively, cache `vote_options` in the vote payload (it is already in the `:sessions` cache entry) and pass a struct with the real options.

#### 18. [FIXED] Post-session votes are not validated; one bad value breaks the session's report permanently

`lib/premiere_ecoute/sessions/scores/post_session_vote.ex:40` · sessions · security · confirmed

**Evidence.** `submit/3` maps `votes` straight into `Vote.create_all(on_conflict: :nothing)` without checking `value in session.vote_options` or that `track_id` belongs to the session. The caller `session_live.ex:78` builds the selections from raw client params: `Map.put(selections, String.to_integer(track_id), value)`. `Report.generate/1` then runs `String.to_integer/1` on every vote value in numeric mode (`report.ex:146`, `to_integer(x) when is_binary(x), do: String.to_integer(x)`). The read paths call it with a hard match, e.g. `{:ok, report} = Report.generate(session)` at history.ex:504 and session_live.ex:32.

**Failure scenario.** An authenticated viewer who did not vote in a stopped 0-10 session sends a crafted `set_post_vote` event with `%{"track_id" => "1", "note" => "abc"}`, then `submit_post_votes`. The row is inserted. Every later `Report.generate` for that session raises ArgumentError: the retrospective page, the history details and the session page all crash. A value of "9999" instead silently skews the averages, and an arbitrary track_id adds a phantom track to the summaries.

**Fix.** In `submit/3`, reject any value not in `session.vote_options` and any track_id that is not among the session's tracks, before inserting. Also make `Report.to_integer` tolerant (use `Integer.parse` and skip invalid values) so a bad row cannot take down report generation.

#### 19. Review edit accepts client-supplied user_id/session_id/role (mass assignment)

`lib/premiere_ecoute_web/live/sessions/session_live.ex:201` · web · security · confirmed

**Evidence.** `Review.changeset/2` casts `:role, ..., :session_id, :album_id, :user_id` (lib/premiere_ecoute/sessions/listening_session/review.ex:63-74). SessionLive does `review -> Reviews.update(review, params)` with raw `%{"review" => params}` from the socket. AlbumLive does the same at album_live.ex:137. RetrospectiveLive does `Reviews.update(review, Map.merge(params, extra))` at retrospective_live.ex:174, where `extra` only overrides session_id/album_id. On create, `Reviews.create` overwrites `user_id`, but `role` still comes from the client. The template even sends it as `<input type="hidden" name="review[role]" ...>` (session_live.html.heex:691).

**Failure scenario.** A logged-in viewer edits their own review and adds `review[user_id]=<victim id>` to the phx-submit payload. The review is re-attributed to the victim and shown under the victim's name. Sending `review[role]=streamer` makes a viewer's review render as the streamer's review and sort first (`list_for_session` orders `role = 'streamer'` first). Sending `review[session_id]=<any id>` in SessionLive attaches the review to an arbitrary, possibly private, session.

**Fix.** Split `Review.changeset` into an internal changeset (role, user_id, session_id, album_id set server-side with `put_change`) and a user changeset that casts only content, tags, rating, like, watched_on and watched_before. Derive `role` on the server from `session.user_id == current_user.id` and drop the hidden input.

#### 20. [FIXED] Post-session votes are inserted unvalidated; one bad value permanently breaks the session report

`lib/premiere_ecoute_web/live/sessions/session_live.ex:80` · web · correctness · confirmed

**Evidence.** `handle_event("set_post_vote", %{"track_id" => track_id, "note" => value}, ...)` stores any client string: `Map.put(..., String.to_integer(track_id), value)`. `Sessions.submit_post_votes` then goes to `Vote.create_all(on_conflict: :nothing)` (scores/post_session_vote.ex:55), which is a raw `Ecto.Multi.insert_all` with no changeset. Nothing checks `value in session.vote_options` or that track_id belongs to the session. Report.generate then runs `String.to_integer(x)` in `to_integer/1` (report.ex:146) for numeric sessions, and RetrospectiveLive runs `String.to_integer(vote.value)` (retrospective_live.ex:295, 333).

**Failure scenario.** A viewer who has not voted pushes `set_post_vote` with `note: "abc"` (or `"99999"`) through the socket, then `submit_post_votes`. The row is persisted. From then on `Report.generate/1` raises ArgumentError for that session. SessionLive mount does `{:ok, report} = Report.generate(listening_session)`, so the session page crashes for every visitor. The retrospective page's report fails too, and the live dashboard summary as well. With a large number instead, averages are silently skewed.

**Fix.** In `PostSessionVote.submit/3`, reject votes whose value is not in `session.vote_options` or whose track_id is not one of the session's tracks, before calling insert_all. Make the report parsing tolerant: use `Integer.parse` and skip values that fail. Replace `{:ok, report} = Report.generate(...)` with a case that renders an error state.

### Medium (42)

#### 21. Spotify album and artist-albums fetches ignore pagination and silently truncate

`lib/premiere_ecoute/apis/music_provider/spotify_api/albums.ex:33` · apis · correctness · confirmed

**Evidence.** `Enum.map(data["tracks"]["items"], ...)` uses only the embedded first page. The fixtures show `"limit": 50` and a `next` field that is never followed. `Artists.get_artist_albums/1` requests `/artists/#{artist_id}/albums?include_groups=album` with the default `limit` (20) and never follows `next` (artists.ex:93-94), yet `EnrichDiscography` relies on it for the full discography.

**Failure scenario.** A deluxe or compilation album with more than 50 tracks is loaded for a listening session and only the first 50 tracks exist. Votes, track markers and playback queueing (`add_item_to_playback_queue(%Album{})`) skip the rest, while `total_tracks` says more. An artist with more than 20 studio albums gets a partial discography.

**Fix.** Reuse the playlist approach: read `tracks.total` and fetch `/albums/{id}/tracks?offset=50&limit=50` pages. For artist albums use `limit=50` and follow `next` up to a sane bound.

#### 22. Twitch refresh-token failures are never classified as invalid_grant, so revoked Twitch accounts are never disconnected

`lib/premiere_ecoute/apis/streaming/twitch_api/accounts.ex:101` · apis · correctness · confirmed

**Evidence.** `renew_token/1` passes the response through the generic `TwitchApi.handle(200, ...)`, so any failure becomes `{:error, "Twitch API error: 400"}`. `OauthToken.refresh_locked/4` disconnects only on `{:error, :invalid_grant}`, and only Spotify's client produces that (spotify_api/accounts.ex:108-110). Per Twitch's docs, an invalid or revoked refresh token returns 400 `{"status":400,"message":"Invalid refresh token"}`.

**Failure scenario.** A streamer revokes the app's Twitch connection. Every `maybe_renew_token(scope, :twitch)` call, from the bot, EventSub, polls and `TokenRenewal` callers, retries the refresh under a DB row lock, logs 'Failed to renew twitch token' and continues with the expired access token, which yields 401s everywhere. For the bot, `Bot.get/0` caches the stale user for 5 minutes and `TwitchQueue` keeps sending chat messages that fail.

**Fix.** Match `{:ok, %{status: 400, body: %{"message" => "Invalid refresh token"}}}` (and 401) in `Twitch renew_token/1` and return `{:error, :invalid_grant}`, as the Spotify client does. Add a test next to the existing Spotify `invalid_grant` test.

#### 23. TwitchQueue drops messages on send failures and can crash with its whole backlog

`lib/premiere_ecoute/apis/streaming/twitch_queue.ex:95` · apis · correctness · confirmed

**Evidence.** `apply(Chat, action, [bot, message])` is followed unconditionally by `{:ok, message}`, and the `{:error, _}` result of `do_send_chat_message` (401, Twitch's own 429, network error) is ignored. `do_send_chat_announcement` always returns `:ok`. Both `handle_cast` and `handle_info(:retry)` do `{:ok, bot} = maybe_refresh_bot(bot)`, and `Bot.get/0` can return `{:error, nil}` on DB or renewal errors. The HTTP call runs synchronously inside the singleton GenServer.

**Failure scenario.** When the bot token expires and renewal fails, or Twitch returns 429 despite the local limiter (limits are per bot and shared with other apps), each queued vote-open or announcement message is silently lost. If `Bot.get()` returns an error while messages are queued (`circuit: :open`), the GenServer crashes with a MatchError and every pending message is discarded.

**Fix.** Treat `{:error, _}` from Chat as a retryable failure: requeue with backoff and open the circuit on a 429, reading `Ratelimit-Reset`. Replace the `{:ok, bot} =` matches with a `case` that keeps the old bot and schedules a retry. Consider a bounded retry count per message.

#### 24. API call metrics use the raw URL path as a Prometheus tag (unbounded cardinality)

`lib/premiere_ecoute/telemetry/api_metrics.ex:26` · apis · ops · confirmed

**Evidence.** `url: request.url.path` is emitted and declared as a tag: `tags: [:provider, :method, :url, :status]`. The paths embed IDs and free text: `/albums/#{album_id}`, `/artists/#{id}/top-tracks`, `/playlists/#{id}/items`, Wikipedia `/page/summary/#{URI.encode(title)}`, Tidal `/searchResults/#{URI.encode(query)}` (user search input), and MusicBrainz and Deezer IDs.

**Failure scenario.** Every distinct album, artist, playlist, search string or Wikipedia title creates a new time series. The PromEx and telemetry_metrics_prometheus ETS table and the `/metrics` payload grow without bound as the discography enrichment jobs run. Scrape latency rises and Grafana Cloud series costs grow over time.

**Fix.** Tag with a route template instead, for example with `Req.merge(path_params: ...)` and `url: "/albums/:id"` so `request.options[:path_params]` or a template can be reported. Otherwise normalize IDs out of the path with a regex, or drop `:url` and tag with a static `operation` name passed through `telemetry` options.

#### 25. Default Req retry sleeps for Spotify's Retry-After with no cap on all catalog GETs

`lib/premiere_ecoute_core/api.ex:66` · apis · performance · confirmed

**Evidence.** `new/1` builds `Req.new()` with no `:retry`, `:max_retries` or `:retry_delay` options. Req 0.7 defaults to `:safe_transient`, which retries GET requests on 408/429/5xx. For 429/503 it takes the delay from the `Retry-After` header (deps/req/lib/req/steps.ex:1824-1834) and retries up to 3 times. Only the player endpoints opt out (`retry: false`, player.ex:28/208/250). Search, albums, artists, playlists, `/me`, Deezer, Tidal, MusicBrainz, Wikipedia, YouTube and Genius all keep the default. The `CircuitBreaker` is not attached to any of them.

**Failure scenario.** Spotify puts an app into rate-limit penalty and returns `Retry-After: 3600` or more (large values are common for development-mode apps). A streamer types in the album search box. The LiveView's `SpotifyApi.search_albums/1` call blocks the LiveView process for up to 3×Retry-After inside `Process.sleep` and the UI freezes. Oban enrichment jobs (EnrichDiscography, Genius and MusicBrainz lookups) tie up their queue slots in the same way. Meanwhile other processes keep hitting the API, which prolongs the ban.

**Fix.** Set a default in `new/1`: either `retry: false` plus the circuit breaker for everything, or a `retry` function that returns `{:delay, min(retry_after_ms, 2_000)}` and gives up when Retry-After exceeds a few seconds. Attach `circuit_breaker/1` in `new/1` so all clients share the app-wide rate-limit state, not only `get_playback_state`.

#### 26. The HMAC plug reads the body and discards the updated conn, so Plug.Parsers re-reads it from stale adapter state

`lib/premiere_ecoute_web/plugs/twitch_hmac_validator.ex:36` · apis · correctness · plausible

**Evidence.** `{:ok, body, _} <- read_body(conn)` throws away the returned conn, and the later `Plug.Parsers` in endpoint.ex reads again from the original adapter struct. In Bandit (`deps/bandit/lib/bandit/http1/socket.ex:212-225`) the socket struct tracks `buffer`/`unread_content_length` functionally. The second read replays only the bytes buffered with the headers, then tries to `recv` bytes the first read already consumed. `BuyMeACoffeeHmacValidator` has the same pattern. Tests pass because `Plug.Adapters.Test.Conn` state is immutable, so the stale read still returns the full body.

**Failure scenario.** The request works only while the entire body arrived in the same socket read as the headers. A larger EventSub payload that spans reads (long chat message with fragments or emotes, a poll with many choices, or the proxy chunking differently) makes Plug.Parsers block until read_timeout and then fail. The webhook errors and Twitch eventually revokes the subscription after repeated failures.

**Fix.** Use a custom `Plug.Parsers` `:body_reader` that caches the raw body in `conn.assigns[:raw_body]`, and verify the HMAC in the controller or router pipeline from that. Or at least thread the returned conn through, and put the parsed body in place so Parsers does not re-read.

*Verifier:* The code matches the report: `{:ok, body, _} <- read_body(conn)` discards the new conn, the plug runs in the endpoint before Plug.Parsers, and the adapter is Bandit 1.12.5. Bandit's HTTP1 read_data keeps buffer and unread_content_length in the returned transport (socket.ex:212-225), so a stale adapter would try to recv bytes that were already consumed. Whether this triggers in production depends on whether the proxy delivers headers and body in one recv. It likely works today for typical EventSub sizes, so it is unproven in production but real.

#### 27. Web Endpoint starts before Repo, Oban and the domain supervisor, and stops after them

`lib/application.ex:16` · core · ops · confirmed

**Evidence.** mandatory = [
  {Task, &PremiereEcouteCore.Registry.init/0},
  PremiereEcouteWeb.Supervisor,
  PremiereEcoute.Supervisor
]
PremiereEcouteWeb.Supervisor starts Phoenix.PubSub, Presence, PremiereEcouteWeb.Endpoint and Mcp.Supervisor (lib/premiere_ecoute_web/supervisor.ex:6-14). PremiereEcoute.Supervisor then starts Repo.Supervisor, which holds Repo, Vault and Oban. A one_for_one supervisor stops its children in reverse start order, so on shutdown the backend (Repo, Oban, caches, TwitchQueue) goes down first while the Endpoint is still accepting and draining requests. The Phoenix convention is Repo, then PubSub, then Endpoint last.

**Failure scenario.** During a deploy or restart, Twitch EventSub keeps POSTing webhooks and browsers keep reconnecting their LiveViews. Requests that reach the Endpoint before Repo is up, or after it has stopped, fail with errors like `could not lookup Ecto repo PremiereEcoute.Repo because it was not started` or `DBConnection.ConnectionError`. The results are 500s on /webhooks/twitch (Twitch retries, and may eventually revoke the subscription), lost chat votes during the shutdown drain, and LiveView mount crashes during boot.

**Fix.** Split the tree into infrastructure, domain and web. Start PubSub, Repo, Vault and the EventStore first, then the domain supervisors and caches, then Oban, and put Endpoint and Mcp last. Move Phoenix.PubSub out of the web supervisor: the domain broadcasts on it, so the domain layer currently depends on the web supervisor having started.

#### 28. [REJECTED] Accounts.Notifier is an EventStore Subscriber that is never started in production

`lib/premiere_ecoute/accounts/notifier.ex:8` · core · correctness · confirmed

**Evidence.** use PremiereEcouteCore.Subscriber, stream: "users"
...
%AccountCreated{} = event -> PremiereEcoute.mailer().dispatch(event)
%AccountDeleted{} = event -> PremiereEcoute.mailer().dispatch(event)
The only place it is started is test/premiere_ecoute/accounts/notifier_test.exs:11 (`start_supervised`). It is not a child of Accounts.Supervisor (whose children are only `{Cache, name: :users}`) or of any other supervisor. PremiereEcouteCore.Subscriber also uses a transient `Store.subscribe`, with no name and no acknowledgement or checkpoint.

**Failure scenario.** A user signs up or deletes their account. AccountCreated or AccountDeleted is appended to `users`, but nothing is subscribed, so the welcome and deletion emails are never sent. The tests pass because they start the process by hand. Even if the Notifier were added to the tree, any event appended while it is down or restarting would be missed, because transient subscriptions do not replay.

**Fix.** Either add it to Accounts.Supervisor with a persistent subscription (`subscribe_to_stream` with a subscription name and `ack/2`), or delete the module and its test if the feature is intentionally off.

#### 29. Discography.Supervisor.async filters for {:ok, _}, but async_stream links tasks, so a crash or timeout kills the caller

`lib/premiere_ecoute/discography/supervisor.ex:14` · core · correctness · confirmed

**Evidence.** PremiereEcoute.Discography.TaskSupervisor
|> Task.Supervisor.async_stream(enumerable, function, timeout: 30_000)
|> Stream.filter(&match?({:ok, _}, &1))
`Task.Supervisor.async_stream/4` links each task to the caller, and its default `on_timeout: :exit` exits the caller. `{:exit, _}` tuples are only produced by `async_stream_nolink` or by `on_timeout: :kill_task`, so this filter can never drop a failure; any failure takes down the caller.

**Failure scenario.** EnrichAlbum or EnrichArtist runs lookups in parallel through `Supervisor.async`. One provider lookup raises (for example a `MatchError` on an unexpected API body) or takes more than 30 seconds. The whole Oban job exits and every sibling result is discarded, which is the opposite of the best-effort behaviour the filter suggests.

**Fix.** Use `Task.Supervisor.async_stream_nolink(..., on_timeout: :kill_task)` so the `{:ok, _}` filter does what it appears to do, and log the `{:exit, reason}` entries it discards.

#### 30. [RISK ACCEPTED] Store.append always returns :ok, is outside the Repo transaction, and writes two streams non-atomically

`lib/premiere_ecoute/events/store.ex:80` · core · correctness · confirmed

**Evidence.** if opts[:stream] do
  __MODULE__.append_to_stream(singular(opts[:stream]) <> to_string(event.data.id), :any_version, [event])
  __MODULE__.link_to_stream(plural(opts[:stream]), :any_version, [event.event_id])
end
:ok
account_compliance.ex:96 does `:ok = Store.append(%AccountDeleted{id: user.id}, stream: "user")` inside an `Ecto.Multi.run`, but EventStore uses its own connection pool, so the append is neither part of the Multi nor rolled back with it. Store.ok, Store.error and Store.any (lines 97-131) have the same issue.

**Failure scenario.** The EventStore connection is saturated, or the append hits a serialization error. `append_to_stream` returns `{:error, reason}`, which is discarded. The domain write has already committed, so the audit event (AccountCreated, AlbumAdded, AddedToWantlist) is lost with no log. Analytics that aggregate these events (analytics/events.ex) then under-count. For account deletion, the `:ok =` match is always true, and if the Repo transaction later fails at commit, an AccountDeleted event exists for a user that still exists. If the append succeeds and `link_to_stream` fails, the event is in `user-<id>` but missing from `users`.

**Fix.** Return and pattern-match the results of append_to_stream and link_to_stream, and at least log failures. For events that must be consistent with the database, write them in the same Postgres transaction (EventStore accepts a `conn:` option) or through an outbox table that the Multi inserts into.

#### 31. CommandBus has no transaction boundary: a command commits state and then returns {:error, []} without emitting events

`lib/premiere_ecoute/sessions/listening_session/command_handler.ex:277` · core · correctness · confirmed

**Evidence.** {:ok, %{album: album}} <- ListeningSession.start(session),   # Repo.update status: :active (committed)
{:ok, _} <- maybe_toggle_playback_shuffle(spotify_disabled, scope),  # Spotify HTTP call
{:ok, _} <- maybe_set_repeat_mode(spotify_disabled, scope),
...
reason ->
  Logger.error("Cannot start listening session due to: #{inspect(reason)}")
  {:error, []}
CommandBus.apply (command_bus.ex:35-57) only runs validate, then handle, then dispatches events. Nothing wraps a handler in a transaction or compensates on failure. SkipNextTrack (lines 352-374) follows the same pattern: `ListeningSession.next_track` commits `current_track_id`, and a later step can still fail and return `{:error, []}`.

**Failure scenario.** A streamer starts an album session and Spotify returns 5xx or 429 on the shuffle or repeat call. The circuit breaker's global 503 rule makes this more likely. The session row is already `:active` with `started_at` set, but SessionStarted is never dispatched: no track marker is created, the instruction and promo jobs are not scheduled, and nothing is broadcast on `playback:<user_id>`. The caller receives `{:error, []}` with no reason to display. Starting any other session now fails with "You already have an active listening session" because `has_active_session?` sees this one.

**Fix.** Do the external, fallible calls (device check, shuffle, repeat, Twitch resubscribe) before the state transition, or treat them as best-effort the way `playback` already is. Alternatively, run the database mutation and event creation inside `Repo.transact` and add an explicit compensating step. Return a real error reason instead of `{:error, []}`.

#### 32. [REJECTED] Oban starts before the caches and GenServers its jobs use, so jobs at boot lose messages silently

`lib/premiere_ecoute/supervisor.ex:11` · core · ops · plausible

**Evidence.** children: [ Telemetry.Supervisor, Repo.Supervisor, Events.Supervisor, Accounts.Supervisor, Apis.Supervisor, ..., Sessions.Supervisor, Collections.Supervisor, ...]. Repo.Supervisor starts `{Oban, Application.fetch_env!(:premiere_ecoute, Oban)}` (lib/premiere_ecoute/repo/supervisor.ex). The :tokens and :subscriptions caches and TwitchQueue are in Apis.Supervisor, and the :sessions cache is in Sessions.Supervisor, all of which start later. TwitchQueue.push is `GenServer.cast(__MODULE__, ...)` (twitch_queue.ex:41), which never fails when the name is not registered. Shutdown runs in reverse, so these dependencies stop while Oban is still draining jobs.

**Failure scenario.** A deploy happens while a listening session has scheduled ListeningSessionWorker jobs, such as vote windows or `send_promo_message`. When the node boots, Oban immediately runs the due jobs. `Cache.put(:sessions, ...)` returns `{:error, :no_cache}`, so the `with` in listening_session_worker.ex:44 falls through. Chat messages are cast to a TwitchQueue that does not exist yet and are dropped without any log. The same happens during Oban's graceful shutdown: running jobs outlive the caches and TwitchQueue they need.

**Fix.** Start Oban as the last backend child, after every domain supervisor, so it starts last and stops first. Separately, make TwitchQueue.push detect a missing process with `GenServer.whereis/1` and return an error.

*Verifier:* The ordering is confirmed: Repo.Supervisor (with Oban) starts before Apis.Supervisor (tokens/subscriptions caches, TwitchQueue via Streaming.Supervisor) and Sessions.Supervisor (the :sessions cache). TwitchQueue.push is a bare GenServer.cast (twitch_queue.ex:41), so it drops messages silently. Cache.put is not silent, though: it logs 'Cannot write into cache' (cache.ex:62-64). At boot the window is only the few milliseconds of sequential child starts. The shutdown case, where Oban drains jobs after the caches and TwitchQueue have stopped, is the more realistic path. Neither case was proven at runtime.

#### 33. EventBus is synchronous, allows one handler per event, and ignores or propagates handler failures

`lib/premiere_ecoute_core/event_bus.ex:27` · core · architecture · confirmed

**Evidence.** def dispatch([event | events]) do
  dispatch(event)
  dispatch(events)
end
...
handler -> handler.dispatch(event)
In CommandBus.apply the call sits inside `tap`, so its result is discarded. Registry.init (registry.ex:19-31) does `:persistent_term.put(c, h)`, so the last handler that declares an event overwrites any earlier one without warning. A module that fails `Code.ensure_compiled` is skipped without a log (`{:error, _} -> :ok`). Registry.init also runs as an async `{Task, ...}`, so it races with the rest of the boot.

**Failure scenario.** (1) A handler raises, for example `Accounts.get_user!` in the SessionPrepared handler or a Repo error in `add_track_marker`. The exception propagates into the LiveView or Oban job that called `PremiereEcoute.apply/1` after the command's database writes have committed, and any remaining events in the list are never dispatched. (2) A handler returns `{:error, _}` and nobody sees it. (3) A second handler that declares `SessionStarted`, for analytics or notifications, silently replaces ListeningSession.EventHandler depending on its position in the config list, and sessions stop scheduling vote jobs. (4) The SessionPrepared handler calls `PremiereEcoute.apply(%StartListeningSession{...})` from inside dispatch (event_handler.ex:63), which nests a second command inside the first caller's stack.

**Fix.** Store a list of handlers per event, and raise at boot on duplicate or unknown handlers or events. Run Registry.init synchronously, as a plain function in start/2, before children start. Choose one error policy: either rescue and log per handler so dispatch continues, or move side effects into Oban jobs enqueued in the same transaction as the state change (an outbox) so they can be retried.

#### 34. ON DELETE RESTRICT from collection_sessions stops users removing library playlists, and the delete raises instead of returning an error

`lib/premiere_ecoute/playlists/library_playlist.ex:115` · data · correctness · confirmed

**Evidence.** The migration has `add :origin_playlist_id, references(:library_playlists, on_delete: :restrict)` and the same for `destination_playlist_id` (20260309000001_create_collection_sessions.exs:13-15). `LibraryPlaylist.delete/2` calls `playlist |> Repo.delete()` on a bare struct, so no changeset declares `foreign_key_constraint`/`no_assoc_constraint`. The caller in playlist_live.ex:279 only matches `{:ok, _} | {:error, _}`.

**Failure scenario.** A user who ever ran a collection session on a playlist clicks 'remove from library'. Postgres raises a foreign key violation, Ecto turns it into an `Ecto.ConstraintError` raise, and the LiveView process crashes. The 'Failed to remove playlist' flash is never shown, and the playlist can't be removed while any collection session, including finished ones, points to it.

**Fix.** Choose the behaviour on purpose. Either cascade or nilify (`on_delete: :delete_all` or `:nilify_all` with nullable columns) for finished collection sessions, or keep RESTRICT and delete through a changeset with `no_assoc_constraint`/`foreign_key_constraint`, so the user sees an explicit error.

#### 35. ListeningSession.preload/1 and Album.preload/1 preload lists one entity at a time (N+1 over about 10 associations)

`lib/premiere_ecoute/sessions/listening_session.ex:98` · data · performance · confirmed

**Evidence.** `def preload(entities) when is_list(entities), do: Enum.map(entities, &preload/1)`. Each element then calls `Repo.preload(entity, root, force: true)` with `root: [user: [:twitch, :spotify], album: [:tracks, :artists], current_track: [], playlist: [:tracks], current_playlist_track: [], single: [:artists], track_markers: [], speech_markers: [], session_notes: []]`. Album.preload does the same (album.ex, `Enum.map(entities, &preload/1)`). Callers that pipe `Repo.all() |> preload()`: active_sessions, upcoming_sessions_from_followed, stopped_sessions_from_followed, missed_sessions_from_followed, current_session, list_for_artist (unbounded, two queries), and page_for_user (`Enum.map(page.entries, &preload/1)`).

**Failure scenario.** A home page listing 10 followed sessions runs roughly 10 × 15 = 150 queries and loads every track, marker and note of every session only to render cards. `list_for_artist` for a prolific artist has no limit and grows without bound.

**Fix.** Preload lists in one batched `Repo.preload(list, root)` call, then map `put_album_artist/1` over the result. Define a lighter preload for list views without markers, notes or playlist tracks. Add a limit and pagination to `list_for_album`/`list_for_artist`.

#### 36. Every page view and every batch of 5 votes rebuilds and rewrites the whole session report, loading all votes several times

`lib/premiere_ecoute/sessions/retrospective/report.ex:100` · data · performance · confirmed

**Evidence.** `generate/1` does `Vote.all(where: [session_id: ...])` and `Poll.all(...)`, then `get_by(session_id:)`. Because of `root: [:votes, :polls]`, that call preloads all votes and polls again. Then it runs `Repo.update`, and `preload(report)` loads them a third time. It runs from MessagePipeline once per batch of 5 votes (batch_size: 5), which is O(n²) over a session. It also runs on read paths: session_live.ex:32 (public page mount, which runs twice per visit, and it preloads `report: [:votes, :polls]` first), retrospective_live.ex:33, and History.get_*_session_details (MCP). overlay_live.ex:274 calls `Report.get_by`, which loads every vote, on every summary broadcast. Per-track scoring filters the full vote list once per track (O(tracks × votes)).

**Failure scenario.** A 12-track session with 300 active chatters produces about 3,600 votes, which means about 720 batches. Each batch reads up to 3,600 rows three times and rewrites the whole JSON report, and each connected overlay reloads all votes as well. Anonymous viewers opening the public session page each trigger an UPDATE on `reports`. The pipeline runs with concurrency 1, so votes back up behind report generation during busy streams.

**Fix.** Compute summaries in SQL (`GROUP BY track_id` with count/avg/count distinct), or update the summary for the affected track only. Remove `:votes`/`:polls` from Report's `root`, or use a lighter `get_by` in generate. Make read paths read the stored report and not call `generate`. Throttle report regeneration in the pipeline, e.g. at most once per second per session. Separately, `generate` checks with `get_by` and then inserts, and the changeset has no `unique_constraint(:session_id, name: :reports_session_id_unique_index)`, so concurrent first generations raise `Ecto.ConstraintError`. Use an upsert with `on_conflict`.

#### 37. Billboard submissions stored as a JSONB array and rewritten whole from in-memory state: concurrent submissions are lost and index-based removals hit the wrong entry

`lib/premiere_ecoute/billboards.ex:47` · domains · concurrency · confirmed

**Evidence.** `update_billboard(billboard, %{submissions: [submission | billboard.submissions]})`. `remove_submission/2` and `toggle_submission_review/2` also rewrite the full array from `billboard.submissions`, addressing entries by positional `index`. BillboardShowLive passes the possibly stale `socket.assigns.billboard`. There is no row lock or optimistic locking, and new submissions are prepended, which shifts all indexes.

**Failure scenario.** During a stream, two viewers submit within the same few milliseconds. Both read the same array and the last UPDATE wins, so one submission (and its deletion token) disappears while its author was told it succeeded. Separately, the streamer's page loaded the billboard before a new submission arrived. Clicking remove on index 3 deletes a different submission (indexes shifted by the prepend) and also drops every submission added since page load.

**Fix.** Move submissions to their own table (billboard_id, url, pseudo, deletion_token, reviewed) with a unique index on (billboard_id, url) and address rows by id. At minimum, append atomically in SQL (`submissions = submissions || $1`) under `SELECT ... FOR UPDATE` and address entries by deletion_token/id rather than index.

#### 38. provider_ids JSONB lookups cannot use the partial unique expression indexes, so every lookup is a sequential scan

`lib/premiere_ecoute/discography/album.ex:140` · domains, data · performance · confirmed

**Evidence.** The indexes are `CREATE UNIQUE INDEX album_tracks_spotify_id_unique ON album_tracks ((provider_ids->>'spotify')) WHERE provider_ids ? 'spotify'` (migration 20260314000000). Queries use `fragment("?->>? = ?", a.provider_ids, ^to_string(provider), ^id)` (Album.find_by_provider/create_if_not_exists, Track.find_by_provider, Single.get_by_provider_id, Artist.find_by_provider) or `fragment("?->>'spotify' = ?", ...)` (AddTrack.find_existing, WantlistItem.wantlisted_spotify_ids). None of them include `provider_ids ? 'spotify'`, and Postgres cannot prove the partial predicate from `->>` equality. The parameterised key `?->>?` also defeats expression matching under generic plans. The GIN indexes do not support `->>` equality. Verified on premiere_ecoute_dev with enable_seqscan=off: `WHERE provider_ids->>'spotify'='abc'` gives `Seq Scan ... Disabled: true`, while adding `AND provider_ids ? 'spotify'` gives `Index Scan using album_tracks_spotify_id_unique`.

**Failure scenario.** SyncRadioDiscographyWorker calls `Album.Track.find_by_provider` once per distinct track played yesterday. SyncPlaylistDiscography calls `Album.find_by_provider` per playlist track. EnrichDiscography calls it per artist album. `wantlisted_spotify_ids` joins albums x tracks with a `->>` filter on every radio page render. Each call is a full scan of albums/album_tracks/singles/artists, and cost grows linearly as the discography grows (hundreds of thousands of tracks once enrichment runs for many artists).

**Fix.** Add the matching predicate in every lookup (`where: fragment("? \\? ?", p.provider_ids, ^key) and fragment("?->>? = ?", ...)`, with the key inlined as a literal per provider so the expression matches). Or use containment `provider_ids @> ?::jsonb` against the existing GIN index, e.g. `fragment("? @> ?", a.provider_ids, ^%{"spotify" => id})`. Centralise this in one helper. Also consider unique/expression indexes for tidal/youtube and for artists, which have no uniqueness on provider ids.

#### 39. Automation "Run now" on a recurring automation spawns an extra schedule chain; one-shot and disabled automations can still execute

`lib/premiere_ecoute/playlists/automations/workers/automation_run_worker.ex:30` · domains · correctness · confirmed

**Evidence.** `%Automation{schedule: :recurring} = automation -> AutomationScheduling.schedule(automation); AutomationExecution.run(...)`. `run_now/1` (automation_scheduling.ex:20) enqueues the same worker with the same args, so a manual run also calls `schedule/1` and inserts another next-cron job. Oban has no `unique:` here. `perform` never checks `automation.enabled`. For `:once`, `Automation.update(automation, %{enabled: false})` bypasses `AutomationCreation.disable/1`, so the already scheduled job is not cancelled. `AutomationCreation.enable/1` schedules without cancelling first. `AutomationExecution.run` hardcodes `trigger: :scheduled`.

**Failure scenario.** A user clicks "Run now" three times on an hourly "shuffle playlist" automation. From the next hour on, the automation runs 4 times per tick, and each run schedules another job, so the duplicates persist forever. With destructive steps (empty_playlist, merge, remove_duplicates) this corrupts playlists and floods notifications. Another case: a `:once` automation scheduled for Friday is run manually on Monday. The manual run sets enabled=false, but the Friday job still fires because perform ignores `enabled`.

**Fix.** Pass a `manual: true` arg from `run_now` and skip rescheduling for it. Add `unique: [keys: [:automation_id], states: [:scheduled, :available]]` for scheduled jobs. Check `enabled` in `perform` for non-manual runs. Route the :once disable through `AutomationScheduling.cancel/1`. Make `enable/1` idempotent (cancel then schedule), and record the real trigger.

#### 40. LibraryPlaylist identity [:provider, :playlist_id] contradicts the per-user unique index; lookups by playlist_id alone crash when two users share a playlist

`lib/premiere_ecoute/playlists/library_playlist.ex:9` · domains · correctness · confirmed

**Evidence.** `use PremiereEcouteCore.Aggregate, identity: [:provider, :playlist_id]`, while migration 20251018114958 replaced the global unique index with `unique_index(:library_playlists, [:user_id, :playlist_id, :provider])`. The public submission page does `LibraryPlaylist.get_by(playlist_id: playlist_id)` (submission_live.ex:22), which is `Repo.get_by`. Generated `create_if_not_exists/1` and `exists?/1` also use the wrong identity.

**Failure scenario.** Two streamers both add the same public Spotify playlist to their library (allowed since the index change). Opening `/playlists/<id>/submit` raises `Ecto.MultipleResultsError`, so the viewer submission page returns 500 for both. If it did not crash, it would attach submissions to an arbitrary owner's row.

**Fix.** Set `identity: [:user_id, :provider, :playlist_id]`. Address public submission pages by the internal `library_playlists.id` (or user + playlist_id) rather than the provider playlist_id alone.

#### 41. Events.Store.read silently truncates at 1000 events (EventStore default count), undercounting podcast downloads and truncating GDPR exports

`lib/premiere_ecoute/podcasts.ex:82` · domains · correctness · confirmed

**Evidence.** `def download_count(id) when is_integer(id), do: length(Store.read("podcast_download-#{id}", :event))`. `Store.read/2` calls `read_stream_forward(stream_uuid)` with no count, and deps/eventstore/lib/event_store.ex sets `@default_count 1_000`. The same `Store.read` backs `AccountCompliance` (`Store.read("user-#{scope.user.id}", :raw)`). `Store.append/2` also discards the result of `append_to_stream`/`link_to_stream`, so write failures are invisible.

**Failure scenario.** An episode with 5,000 downloads shows "1000" on ShowDashboardLive (`Podcasts.download_count(e)` per episode, which loads up to 1000 full events into memory for each episode on each mount). A user with more than 1000 events requests a data export and silently gets a partial one.

**Fix.** Replace `download_count` with the existing SQL aggregate (`Statistics.episode_downloads/1` or a COUNT over event_store tables). Make `Store.read` page through `stream_forward/2` (or pass an explicit large count) and log or return errors from `append`.

#### 42. Radio retention cleanup skips users who disabled radio, so their tracks are kept forever

`lib/premiere_ecoute/radio/workers/cleanup_old_tracks.ex:18` · domains · correctness · confirmed

**Evidence.** `Accounts.streamers() |> Enum.filter(fn user -> Accounts.profile(user, [:radio_settings, :enabled], false) end) |> Enum.each(... Radio.delete_tracks_before(user.id, cutoff) ...)`

**Failure scenario.** A streamer uses radio for a month and then disables it. Their `radio_tracks` rows (listening history with timestamps) are never deleted, even though the promised retention is `retention_days` (default 7). The table grows unbounded for every user who ever turned radio off. The same happens if a user stops being a "streamer".

**Fix.** Apply retention to all rows. Group `radio_tracks` by user_id (or iterate all users with tracks), use the profile's retention_days when present and the default otherwise, and run one `delete_all` per user or a single SQL statement joined on the profile setting.

#### 43. LinkProviderTrack stores the first search hit as the equivalent track with no similarity check, and may store nil

`lib/premiere_ecoute/radio/workers/link_provider_track.ex:32` · domains · correctness · confirmed

**Evidence.** `with {:ok, [result | _]} <- Apis.provider(target).search_tracks(query: "#{track.artist} #{track.name}"), {:ok, _} <- Radio.add_provider(track, %{target => Map.get(result.provider_ids, target)})`

**Failure scenario.** A radio track "Intro" by a small artist gets a Deezer search whose top hit is a different artist's "Intro". That Deezer id is persisted on the radio track and later used for wantlists, links and discography sync. `Radio.backward_fill/1` applies this to every radio track ever recorded. If the result lacks the provider key, `%{deezer: nil}` is merged and the track is permanently treated as linked (`p in Map.keys(track.provider_ids)`).

**Fix.** Filter results with `PremiereEcouteCore.Search.filter` on both artist and title (and duration within a few seconds when available), skip when the id is nil, and prefer ISRC matching when the source provider exposes it (discography/isrc.ex already exists).

#### 44. TrackSpotifyPlayback polling chain has no uniqueness; repeated starts create parallel perpetual loops that stop_radio then reports as failures

`lib/premiere_ecoute/radio/workers/track_spotify_playback.ex:10` · domains · concurrency · confirmed

**Evidence.** The worker is declared as `use PremiereEcouteCore.Worker, queue: :spotify, max_attempts: 3` with no `unique:` option. Every path reschedules itself (`__MODULE__.in_seconds(%{user_id: user_id}, ...)`), including the catch-all `{:error, reason}` branch every 30s. It is started from Radio.EventHandler on each `StreamStarted` (`TrackSpotifyPlayback.now`), and from `Radio.start_radio/1` (radio.ex:21) on the home page button. HomeLive `stop_radio` treats only `{:ok, 1}` from `cancel_all` as success.

**Failure scenario.** A streamer clicks "start radio" while their stream is live. Twitch EventSub redelivers `stream.online` (it is at-least-once), or the button is double-clicked. Now N independent chains each poll Spotify, multiplying API calls and rate-limit hits (which trigger more rescheduling) and racing `RadioTrack.insert`'s check-then-insert consecutive-duplicate guard, so duplicate rows appear. `stop_radio` cancels 2 jobs, gets `{:ok, 2}` and flashes "Failed to stop radio". A job that is executing during `cancel_all` (state `executing` is not cancelled) reschedules itself afterwards, so the radio keeps running after StreamEnded.

**Fix.** Add `unique: [keys: [:user_id], states: [:available, :scheduled, :retryable, :executing], period: :infinity]` (or use Oban's replace option), and re-check an enabled/stopped flag before rescheduling. Make stop_radio accept `{:ok, n}` for any n. Apply the same review to `LinkProviderTrack` (enqueued per insert and by `backward_fill`, with no uniqueness).

#### 45. Deploy pipeline never runs database migrations, and rollback cannot undo them

`.github/workflows/release-app.yml:176` · quality · ops · plausible

**Evidence.** The deploy steps are: rsync the release, scp .env, `systemctl restart premiere-ecoute`, then health check. Nothing calls `bin/migrate` (rel/overlays/bin/migrate -> `PremiereEcoute.Repo.Release.migrate`), and `Ecto.Migrator` is only referenced in lib/premiere_ecoute/repo/release.ex. The rollback step (line 208) swaps the release directory back but leaves the schema as it is. The systemd unit is not versioned, so the repo alone cannot show whether an ExecStartPre runs migrations. docs/guides/deployment.md does not mention migrations and still refers to `.github/workflows/main.yml`, which no longer exists.

**Failure scenario.** A commit adds a migration (for example a new column used by a LiveView). The deploy restarts the app on the old schema, and queries fail with `column does not exist` until someone SSHes in to run migrations by hand. The inverse also happens: if migrations were run manually and the health check then fails, the rollback puts old code back on a newer schema.

**Fix.** Add an explicit step before the restart: `ssh ... '/opt/premiere-ecoute/bin/migrate'`. Write migrations to be backward compatible (expand/contract) so the automatic code-only rollback stays safe. Version the systemd unit file in `rel/` and fix the stale workflow name in deployment.md.

*Verifier:* The workflow never calls bin/migrate. rel/overlays/bin/server only runs `premiere_ecoute start`, and nothing in lib calls Ecto.Migrator at boot (only Repo.Release does). The systemd unit is not in the repo, so an ExecStartPre that runs migrations cannot be ruled out. The rollback only swaps directories and leaves the schema as is.

#### 46. Production Repo pool_size of 2 is shared by 13 Oban slots, 3 Broadway vote batchers, LiveViews and webhooks

`config/prod.exs:10` · quality · performance · plausible

**Evidence.** `config :premiere_ecoute, PremiereEcoute.Repo, ssl: false, pool_size: 2` (the EventStore also uses `pool_size: 2`). config.exs:146-156 declares Oban queues with total concurrency 1+1+1+1+5+1+1+1+1 = 13, plus the Pruner/Reindexer/Cron plugins. The scores/poll/collection Broadway pipelines write votes in batches. Everything goes through the same 2 connections. A Sentry search for `DBConnection.ConnectionError` over 90 days returned no issues, so this is a capacity risk under load, not an observed outage.

**Failure scenario.** During a popular listening session, chat votes are batched into the DB while `automations` runs 5 jobs and several viewers load overlays. Checkouts queue past `queue_target` (50ms) and `queue_interval`, so DBConnection starts dropping requests ("connection not available and request was dropped from queue"). Votes are lost or LiveViews crash. This happens on exactly the live-stream path that matters most.

**Fix.** Make the pool size configurable through `POOL_SIZE` in runtime.exs and size it to the Postgres max_connections of the droplet (10 is a common minimum). Alternatively, cut `automations` concurrency. Add a PromEx/Grafana alert on Ecto queue_time.

*Verifier:* prod.exs sets Repo pool_size: 2 and runtime.exs has no override. The 13 Oban slots are confirmed. Contention under load is a real risk, but connections are only checked out per query, and the finding itself says Sentry shows no DBConnection errors, so the impact is unproven.

#### 47. Billboard deletion tokens are brute-forceable (~98k space, no rate limit)

`lib/premiere_ecoute_core/goofy_words.ex:129` · security · security · confirmed

**Evidence.** `def generate_with_number do word = generate(); number = Enum.random(1..999); "#{word}#{number}" end`. The list has about 98 words, so about 98,000 values, and `Enum.random` is not a CSPRNG. `Billboards.SubmissionLive.handle_event("delete_submission", ...)` on the public route /billboards/:id/submission/new calls `remove_submission_by_token`, which deletes the first submission whose token matches, with no attempt limit.

**Failure scenario.** An anonymous user scripts LiveView `delete_submission` events over one websocket and enumerates word×1..999 in minutes. With N submissions on a billboard, each guess has N/98k odds, so they can wipe other viewers' playlist submissions.

**Fix.** Use a high-entropy token (e.g. 16 random bytes, url-safe) with a memorable display alias if needed. Rate-limit delete attempts per socket and IP, and compare tokens with secure_compare.

#### 48. Twitch OAuth login has no state/CSRF check (login CSRF)

`lib/premiere_ecoute_web/controllers/accounts/auth_controller.ex:67` · security · security · confirmed

**Evidence.** `TwitchApi.authorization_url/2` sends `state: state || random(16)`, but the value is never stored. `callback(conn, %{"provider" => "twitch", "code" => code})` never reads or validates `state` before `log_in_user(user)`.

**Failure scenario.** The attacker obtains a fresh Twitch authorization code for their own account and lures the victim to `/auth/twitch/callback?code=<attacker code>`. The victim is silently logged into the attacker's account. Anything they then do (connect Spotify, add a wantlist, upload data, create sessions) lands in the attacker's account.

**Fix.** Generate a random state, put it in the session in request/2, and compare it with `Plug.Crypto.secure_compare` in callback/2. Reject the callback on mismatch and delete the state after use. Apply the same helper to Spotify (see the critical finding).

#### 49. Open redirect in OAuth deny path: redirect_uri taken from query without client validation

`lib/premiere_ecoute_web/controllers/oauth/authorize_controller.ex:62` · security · security · confirmed

**Evidence.** `defp deny(%Plug.Conn{query_params: %{"redirect_uri" => redirect_uri, "state" => state}} = conn), do: redirect(conn, external: redirect_uri <> "?error=access_denied...")`. The redirect_uri is never checked against the client's registered redirect_uris (preauthorize is bypassed on this branch), and there is no client_id check at all.

**Failure scenario.** A logged-in user clicks `https://premiere-ecoute.fr/oauth/authorize?approved=false&redirect_uri=https://phish.example/login` and lands on the attacker's page after passing through the trusted domain. This is useful for phishing, and it is also reachable via GET for the same reason as the consent bypass.

**Fix.** On deny, resolve the client via Boruta (or `Boruta.Oauth.preauthorize`) and redirect only to a validated redirect_uri. Use `Boruta.Oauth.Error.redirect_to_url/1` with an `access_denied` error built from the validated request. Render an error page otherwise.

#### 50. Anonymous write endpoints (album picks, billboard submissions, Spotify search) have no rate limiting

`lib/premiere_ecoute_web/live/sessions/album_pick_submission_live.ex:70` · security · security · confirmed

**Evidence.** The route `/sessions/:username/pick` uses on_mount `:current_scope` only. `handle_event("search_albums", ...)` calls `start_async(:search, fn -> PremiereEcoute.Apis.spotify().search_albums(query) end)` on every event, and `submit_album` calls `AlbumPicks.add_viewer_entry(streamer.id, attrs, pseudo)`, where `pseudo` is untrimmed-length free text. The billboard `submit` event is the same. Only login and podcasts go through `RateLimiter`.

**Failure scenario.** A script floods a streamer's pick pool with junk entries and arbitrary pseudos (shown in the streamer UI and the spin wheel). It can also burn the app's shared Spotify client-credentials quota via search events, which degrades Spotify features for everyone (429s).

**Fix.** Add a per-IP/per-socket limit (the existing Hammer `RateLimiter`) in these handle_event clauses. Validate `submitter` length, cap viewer entries per streamer per window, and consider requiring a Twitch login for submissions.

#### 51. [FIXED] Buy Me a Coffee webhook fails open when the secret is unset (optional in prod config)

`lib/premiere_ecoute_web/plugs/buy_me_a_coffee_hmac_validator.ex:37` · security · security · plausible

**Evidence.** `case Application.get_env(:premiere_ecoute, :buymeacoffee_webhook_secret) do nil -> log_unconfigured(); assign(conn, :buymeacoffee_hmac, true)`. In runtime.exs:24 `buymeacoffee_webhook_secret: env!("BUYMEACOFFEE_WEBHOOK_SECRET", :string, nil)` defaults to nil in prod.

**Failure scenario.** If the env var is missing in prod, anyone can POST `{"type":"donation.created", ...}` to /webhooks/buymeacoffee. That creates fake donation records, which show on the public /admin/donations/overlay and in goal totals. They can also send `donation.refunded` with a real transaction_id to revoke genuine donations.

**Fix.** Make the secret mandatory in prod (`env!("BUYMEACOFFEE_WEBHOOK_SECRET")`) and reject the request when it is unset outside dev/test. Keep the fail-open path, if at all, behind an explicit dev-only flag.

*Verifier:* The code fails open as described: when the secret is nil, it assigns buymeacoffee_hmac=true, and the controller trusts that assign. runtime.exs defaults BUYMEACOFFEE_WEBHOOK_SECRET to nil in every env. Whether prod actually sets the secret cannot be verified from the repo. A warning is logged, but the request is still accepted.

#### 52. start/1 has no status guard and no DB constraint, so a running or stopped session can be restarted

`lib/premiere_ecoute/sessions/listening_session.ex:172` · sessions · correctness · confirmed

**Evidence.** `def start(%__MODULE__{id: session_id, user_id: user_id} = session)` only checks `has_active_session?(user_id, session_id)`, which excludes the session itself. It then sets `status: :active, started_at: DateTime.utc_now`. The migrations have no partial unique index on `(user_id) WHERE status = 'active'`, so the check-then-update is also racy. The API `start` (api/session/dashboard_controller.ex:109) resolves `current_session`, which returns the active session first, then runs Start followed by SkipNext.

**Failure scenario.** A client calls `POST /api/.../start` twice. The second call restarts the already active session: `started_at` is reset, which throws off the SpeechMarker offsets computed from `session.started_at` and the XMEML export timing. The welcome message is posted again, SessionStarted re-schedules instructions and promo, and SkipNext advances one extra track. A double-click on Start in two tabs can also create two active sessions for one user.

**Fix.** Pattern-match `start(%__MODULE__{status: :preparing})` and return `{:error, :invalid_status}` otherwise. Add a partial unique index `CREATE UNIQUE INDEX ... ON listening_sessions(user_id) WHERE status = 'active'`, with `unique_constraint` in the changeset mapping to `:active_session_exists`.

#### 53. Stop runs Twitch side effects before the state change; a Twitch failure leaves the session stuck active

`lib/premiere_ecoute/sessions/listening_session/command_handler.ex:494` · sessions · correctness · confirmed

**Evidence.** In every Stop clause, `{:ok, _} <- Apis.twitch().unsubscribe(...)` and `:ok <- Apis.twitch().send_chat_message(scope, message)` come before `{:ok, session} <- ListeningSession.stop(session)`. Any failure falls through to `{:error, []}`. `ListeningSession.start/1` refuses a new session while another is `:active` (`has_active_session?`).

**Failure scenario.** (a) The Twitch token has expired or the chat API rate-limits, so `send_chat_message` returns an error. Stop fails, the session stays `:active`, and the streamer cannot start any new session ("You already have an active listening session") until Twitch recovers. (b) The API `POST stop` resolves `current_session`, which can be a `:preparing` session. That call unsubscribes chat and posts "The premiere of X is over" to chat, and only then fails with `:invalid_status`.

**Fix.** Check `status == :active` first, then do the state transition (`ListeningSession.stop`), and treat unsubscribe and chat as best-effort afterwards. That can be a SessionStopped handler or the same `:failed` outcome folding already used for Spotify playback.

#### 54. Oban uniqueness keys omit user_id, so jobs for different streamers deduplicate each other

`lib/premiere_ecoute/sessions/listening_session/listening_session_worker.ex:12` · sessions · concurrency · confirmed

**Evidence.** `unique: [period: 5, keys: [:action, :session_id]]`. Several jobs carry no `session_id`: `%{action: "send_instructions", user_id: user_id}` and `%{action: "send_promo_message", user_id: user_id}` (event_handler.ex:77-78). With keys, Oban's uniqueness check compares only those keys, so these jobs are unique by `action` alone, across all users. Oban 2.24's default unique states include `:completed`, so a `close` job that completed less than 5s earlier also suppresses a new `close` for the same session.

**Failure scenario.** (a) Two streamers start sessions within 5 seconds of each other. The second streamer's chat never gets the voting instructions or the promo message. (b) A streamer skips a track (a `close` runs at T) and then stops at T+3s. SessionStopped's `close` is dropped as a duplicate, so the `:sessions` cache entry survives. For `:track` sessions, which do not unsubscribe from chat, votes keep being recorded into the stopped session. For album sessions, votes cast after the next session starts (before its first open) go to the old session id.

**Fix.** Use `keys: [:action, :session_id, :user_id]`, or drop uniqueness for the chat-message jobs. Do not deduplicate `close`: it is idempotent, and dropping it is what causes the stale cache. If uniqueness is still wanted there, restrict `states` to `[:available, :scheduled]`.

#### 55. Free-mode polls store a Single id in polls.track_id, which has a foreign key to album_tracks

`lib/premiere_ecoute/sessions/listening_session/listening_session_worker.ex:255` · sessions · correctness · confirmed

**Evidence.** `open_free_poll` caches `current_track_id: track_id`, where `track_id` is `session.single_id` (command_handler.ex, `track_id: session.single_id`). PollPipeline stores that value as `Poll.track_id`. The migration defines `add :track_id, references(:album_tracks, on_delete: :delete_all), null: false`, and Poll has `belongs_to :track, Track` plus `foreign_key_constraint(:track_id)`. No later migration changes this. There is also a `polls_session_track_index` unique index on `(session_id, track_id)`.

**Failure scenario.** A free session with ≤5 vote options, i.e. poll mode, captures a Single with id 4321. If no album_tracks row has id 4321, the PollStarted insert fails the FK and is only logged ("Failed to upsert poll_id=..."), so the Twitch poll results never reach the report. If an unrelated album track does have id 4321, the insert succeeds but references the wrong row, and deleting that album track cascades and deletes the poll. Opening a second poll for the same captured track violates the (session_id, track_id) unique index.

**Fix.** Drop the FK on `polls.track_id` (votes.track_id already has none) or make it polymorphic like TrackMarker. Reconsider the (session_id, track_id) uniqueness for free mode, where the same track can be polled more than once.

#### 56. [FIXED] Session averages count missing viewer or streamer scores as 0.0

`lib/premiere_ecoute/sessions/retrospective/report.ex:251` · sessions · correctness · confirmed

**Evidence.** Track summaries default missing scores to zero: `viewer_score: viewer_score || if(mode == :numeric, do: 0.0, else: "even")` and `streamer_score: streamer_score || ...`. The session summary then averages over all track summaries: `streamer_score: calculate_average_score(Enum.map(track_summaries, fn t -> t.streamer_score end), mode)` (lines 108-109).

**Failure scenario.** The streamer rates 5 of 12 tracks with an average of 8, and viewers vote on all 12. The session streamer_score comes out as (5*8 + 7*0)/12 = 3.3 instead of 8.0. Likewise, a track with only a streamer vote or only a Twitch poll adds a 0.0 viewer score to the session average. In text mode, the placeholder "even" is counted as a real vote in the session-level majority.

**Fix.** Keep `nil` in the track summaries (or compute the session averages before applying the defaults), and exclude nil values when averaging at the session level. Apply the display defaults only in the view.

#### 57. Public billboard dashboard triggers an expensive, un-deduplicated generation for anonymous visitors

`lib/premiere_ecoute_web/live/billboards/dashboard_live.ex:45` · web · performance · confirmed

**Evidence.** `/billboards/:id/dashboard` is in the `:public_billboard` live_session. On a cache miss, mount runs `start_async(:rankings, fn -> ... results = Billboards.generate_billboard(urls, callback: callback); Cache.put(...) end)`. Nothing prevents concurrent generations.

**Failure scenario.** The billboard link is shared in chat. Before the first generation finishes and fills the cache, every visitor's LiveView starts its own `generate_billboard`, which fetches every submitted playlist from the provider APIs. N concurrent visitors cost N times the API calls and can hit provider rate limits.

**Fix.** Generate billboards in a single Oban job (unique per billboard_id). Have the LiveView subscribe to its progress through PubSub instead of generating inline.

#### 58. Anonymous album-pick submission page has no rate limiting and searches Spotify on each keystroke

`lib/premiere_ecoute_web/live/sessions/album_pick_submission_live.ex:36` · web · security · confirmed

**Evidence.** The moduledoc says it is "Accessible to unauthenticated users". `handle_event("search_albums", %{"query" => query}, socket) when byte_size(query) > 2` does `start_async(:search, fn -> PremiereEcoute.Apis.spotify().search_albums(query) end)`. `submit_album` calls `AlbumPicks.add_viewer_entry(streamer.id, attrs, pseudo)` with a free-text pseudo and no throttle, then broadcasts to the streamer's admin page.

**Failure scenario.** A script opens a socket to `/sessions/<streamer>/pick` and floods `search_albums`, which burns the app-wide Spotify client-credentials quota for every user. It can also call `submit_album` in a loop with many albums and arbitrary pseudos (profanity, for example), filling the streamer's pool and spamming their live admin view.

**Fix.** Require viewer login, or add a per-IP/per-socket rate limit, reusing the existing `Plugs.LoginRateLimit` approach or a Hammer bucket checked in `handle_event`. Validate the length and content of `pseudo`, and cap entries per submitter.

#### 59. OBS overlay leaves Presence when a session stops and never re-joins, so the player can be stopped under a live overlay

`lib/premiere_ecoute_web/live/sessions/overlay_live.ex:194` · web · correctness · confirmed

**Evidence.** On `:session_stopped` the overlay calls `Presence.unjoin(id, :overlay)` (line 224). `handle_info({:session_started, session_id}, socket)` only calls `PremiereEcoute.PubSub.subscribe("session:#{session_id}")` and never calls `Presence.join/2` again. `Presence.handle_metas/4` broadcasts `:no_overlay` when the last `overlay` meta leaves, and `SpotifyPlayer.handle_info(:no_overlay, data)` responds with `{:stop, :normal, data}`. DashboardLive also joins as `:overlay` (dashboard_live.ex:43), which hides the bug while the dashboard is open.

**Failure scenario.** The streamer keeps the OBS browser source open all evening. Session 1 ends, so the overlay unjoins. Session 2 starts from the dashboard, and the overlay receives `:session_started` but stays untracked. The streamer then closes or reloads the dashboard tab. The overlay count drops to 0, `:no_overlay` fires, and the Spotify player process stops. The overlay stops getting playback progress mid-session until OBS reloads the source.

**Fix.** Call `Presence.join(user.id, :overlay)` in the `{:session_started, _}` handler, or never unjoin on `:session_stopped`, since the overlay process is still alive and Presence cleans up on process exit anyway. Unsubscribe from the previous `session:` topic before subscribing to the new one. Handle `ListeningSession.get/1` returning nil.

#### 60. Public overlay mount starts the Spotify player outside connected?/1

`lib/premiere_ecoute_web/live/sessions/overlay_live.ex:61` · web · performance · confirmed

**Evidence.** In `mount_with_user/2`, `_ = PlayerSupervisor.start(session.user.id)` runs whenever the streamer has an active session, on both the dead HTTP render and the socket mount. The route `/sessions/overlay/:username` has no authentication (`on_mount: [{UserAuth, :current_scope}]`).

**Failure scenario.** Any anonymous visitor, or a crawler hitting the overlay URL, spawns or pings a polling player process that uses the streamer's Spotify token and rate limit, even when the streamer runs no overlay. The dead render also starts the player for a request that never upgrades to a socket.

**Fix.** Start the player only from the streamer's authenticated dashboard or command handlers. If the overlay must start it, at least wrap the call in `if connected?(socket)`.

#### 61. SessionLive ignores session visibility and writes the report on every mount

`lib/premiere_ecoute_web/live/sessions/session_live.ex:21` · web · security · confirmed

**Evidence.** `mount(%{"share_token" => share_token, ...})` only checks `ListeningSession.get_by_share_token(share_token)`, then runs `Repo.preload(listening_session, report: [:votes, :polls])` and `{:ok, report} = Report.generate(listening_session)`. RetrospectiveLive, for the same session, enforces `Sessions.can_view_retrospective?/2` (private means owner only). `Report.generate` recomputes the report and does `Repo.insert`/`Repo.update` (report.ex:115-124). It runs on both the dead render and the connected mount, and RetrospectiveLive also calls it on every view (retrospective_live.ex:33).

**Failure scenario.** A streamer marks a session `:private`. Any logged-in viewer who has the `/sessions/<user>/<token>/retrospective` link cannot open the retrospective, but opening `/sessions/<user>/<token>` still shows every score and review. Separately, every page view makes two full vote scans plus two report UPSERTs, so a popular public retrospective turns read traffic into write load.

**Fix.** Apply `Sessions.can_view_retrospective?/2` (or an equivalent policy) in SessionLive. Read the stored report with `Report.get_by(session_id: ...)` instead of generating it on each view. Regenerate it only from the event handlers when votes change, and at most once, guarded by `connected?/1`. Move the `Repo.preload` into the Sessions context.

#### 62. [FIXED] /users/follows is unreachable because /:username is declared first

`lib/premiere_ecoute_web/router.ex:145` · web · correctness · confirmed

**Evidence.** Inside `live_session :users`, the route `live "/:username", UserLive, :show` comes before `live "/follows", FollowsLive, :index`. Phoenix matches routes in declaration order.

**Failure scenario.** A request to `/users/follows` is routed to `UserLive` with `username = "follows"`. `Accounts.get_user_by_username("follows")` returns nil, so the page redirects to `/users`, and the FollowsLive page (follow/unfollow modals) can never be reached. A user who registers the username "follows" would take over the path. No template links to it, which suggests the feature is currently dead.

**Fix.** Move `live "/follows"` above `live "/:username"` (or remove FollowsLive if it is obsolete), and add a router test for the path.

### Low (35)

#### 63. Behaviours have drifted from the implementations and their call sites

`lib/premiere_ecoute/apis/music_provider/spotify_api.ex:84` · apis · testing · confirmed

Any LiveView test for LibraryLive fails with `UndefinedFunctionError` on the mock, which is probably why it has none. A Hammox stub returning `{:ok, nil}` for `get_artist_top_track` fails type checking even though production returns it. The mock contract therefore does not protect callers such as `festivals/services/track_search.ex:57-58`.

**Fix.** Add `get_library_playlists/2` and `start_playback/2` callbacks and widen the return types to `| nil` where the implementation returns nil. Add `authorization_code` to the `Oauth` behaviour (the arity differs per provider, so declare it per provider).

#### 64. Path segments are built with URI.encode/1, which leaves '/', '?' and '#' unescaped

`lib/premiere_ecoute/apis/music_provider/tidal_api/artists.ex:51` · apis · correctness · confirmed

Enriching the artist 'AC/DC' requests `/searchResults/AC/DC` and gets 404, so the artist is never linked to Tidal. The Wikipedia summary for a title containing '/' or '?' hits the wrong route or loses everything after '?'.

**Fix.** Use `URI.encode(value, &URI.char_unreserved?/1)`, or Req's `path_params` with a `:name` placeholder, which encodes the segment correctly.

#### 65. The client-credentials token is cached for its full lifetime and an empty token is sent on failure

`lib/premiere_ecoute_core/api.ex:123` · apis · correctness · confirmed

A request built seconds before expiry (for example the 5-way parallel playlist page fetch) is sent with a token that has just expired and gets 401, which is surfaced as a generic 'Spotify API error: 401'. When Spotify accounts is briefly down, every catalog call makes an extra token request and then a guaranteed 401, which doubles traffic during an outage.

**Fix.** Cache with `expire: (expires_in - 60) * 1_000`. Have `api/0` return or raise a distinct `{:error, :no_token}` instead of sending an empty bearer token.

#### 66. EventSub notifications are not de-duplicated by message id, so Twitch redeliveries are processed twice

`lib/premiere_ecoute_web/plugs/twitch_hmac_validator.ex:37` · apis · security · plausible

The app is slow to answer (GC pause, a slow `PremiereEcoute.apply` of a chat command). Twitch retries the same `channel.chat.message` notification, the vote or `!command` is applied twice and scores are skewed. A captured signed request can also be replayed during the 10-minute window.

**Fix.** After a valid HMAC, `Cache.put(:eventsub_ids, message_id, true, expire: 11 * 60_000)` with a put-if-absent check (`Cachex.put_new` or an `incr` check). Return 204 without dispatching when the id has already been seen.

*Verifier:* The code does not track message IDs; this is confirmed. However, the 'scores skewed' impact is refuted for votes: Vote has a unique constraint on (viewer_id, session_id, track_id), and inserts use on_conflict: :nothing (message_pipeline.ex:87). Double processing can only duplicate non-idempotent !commands or PubSub broadcasts. Replay needs a captured signed request sent over TLS within 10 minutes, so the security framing is weak.

#### 67. Compile-time git call records "fatal: not a git repository" as the commit in Docker builds

`lib/premiere_ecoute.ex:44` · core · ops · confirmed

The production image renders `v0.1.0-fatal: not a git repository (or any of the parent directories): .git` in the layout footer (layouts.ex:126). Any code that uses `version()` for cache-busting or telemetry gets a garbage value.

**Fix.** Pass the commit as a build arg or environment variable (for example `ARG GIT_SHA` read with `System.get_env` at compile time), check the exit status, and fall back to "unknown".

#### 68. The playback-failure flash uses send(self()), which is lost when the command comes from a worker or controller

`lib/premiere_ecoute/sessions/listening_session/event_handler.ex:47` · core · architecture · confirmed

Auto-advance to the next track runs in the Oban worker, and the Spotify start/resume call fails. The warning message goes to the Oban job process, which exits, and the streamer never learns playback failed. The same happens for the REST dashboard API. This is a leaky abstraction: an event handler depends on which process called the command bus.

**Fix.** Broadcast the warning on a user-scoped PubSub topic, such as the existing `playback:#{user_id}`, and have the LiveView turn it into a flash.

#### 69. Aggregate.create_if_not_exists is check-then-insert, and Album.create stores its error changeset as an artist during concurrent enrichment

`lib/premiere_ecoute_core/aggregate.ex:100` · core · concurrency · plausible

EnrichDiscographyWorker imports an artist with ten new albums. Several tasks see no Artist row for that name and all insert it. One wins, and the others get `{:error, %Changeset{errors: [name: "has already been taken"]}}`. `elem(..., 1)` passes that changeset to `put_assoc(:artists, [changeset])`, which makes the album insert fail. The album is then dropped by `Stream.filter(&match?({:ok, _}, &1))`, so part of the discography is missing and no error is logged.

**Fix.** Make the generated create_if_not_exists race-safe: use `Repo.insert(on_conflict: :nothing, conflict_target: identity)` and then re-read, or catch the unique-constraint error and fall back to `get_by`. In Album.create, match on `{:ok, artist}` explicitly instead of using `elem/2`.

*Verifier:* The check-then-insert is real (aggregate.ex:100-105). The artists table has a unique index on name, and album.ex passes elem(...,1) to put_assoc, which can be a changeset. However, create_discography receives the main artist already persisted with a Spotify id, so get_by(name) finds it and there is no race for that artist. Only new featured co-artists shared across several albums processed in parallel can race. That is narrower than the finding claims.

#### 70. Circuit breaker opens for all users of an API on a single 503

`lib/premiere_ecoute_core/api/circuit_breaker.ex:36` · core · performance · confirmed

One user's `/me/player` call gets a transient Spotify 503. For the next 30 seconds every user's playback-state request is halted locally with a RuntimeError, and every open LiveView shows the rate-limit banner via CircuitBreakerMonitor. A single flaky response becomes an outage for all users.

**Fix.** Open the circuit only after N failures within a time window. Keep the global key for real app-level 429s, and scope 503 handling per endpoint or per user.

#### 71. PremiereEcouteCore declares deps: [] but depends on the domain, and ships a debug module and a broken macro

`lib/premiere_ecoute_core/channel.ex:45` · core · architecture · confirmed

Boundary cannot see these references because most of them sit inside quoted code that compiles in the caller, so the rule that the core has no deps holds only on paper. The core cannot be reused or tested without the domain Repo, User and Gettext. The first module that does `use PremiereEcouteCore.Dataflow.Sink` will fail at runtime with UndefinedFunctionError. `PremiereEcoute.Prout` ships in production and pollutes `ChannelRegistry.all/0`.

**Fix.** Delete `PremiereEcoute.Prout` and the unused Sink `__using__`, or fix it. Move the FunWithFlags impls into Accounts. Inject Repo and Gettext through `use` options (for example `use Aggregate, repo: PremiereEcoute.Repo`), or declare the real dependency in the Boundary config.

#### 72. SessionNotPrepared events are returned for dispatch but no handler is registered, so every failure logs an error

`lib/premiere_ecoute_core/command_bus.ex:49` · core · correctness · confirmed

Every failed session preparation writes a misleading `No registered handler` error log, which adds noise to Sentry and Grafana alerts, and the event itself has no effect. Callers receive `{:error, [%SessionNotPrepared{}]}` or `{:error, []}` instead of a reason they can show the user.

**Fix.** Register SessionNotPrepared in a handler, or stop returning it as an event. Consider separating the error reason from the error events, for example `{:error, reason, events}`, so callers always get a displayable reason.

#### 73. Search.sort never sorts the string-keyed billboard submissions

`lib/premiere_ecoute_core/search.ex:61` · core · correctness · confirmed

`Map.get(submission, :added_at)` is always nil, so every comparison returns `:eq` and the list comes back in its original order. The admin "sort by date" view silently does nothing. Any non-binary value, such as a DateTime struct, is also never sorted.

**Fix.** Call it with "added_at", and make compare_dates handle DateTime and NaiveDateTime values and fall back to a normal term comparison instead of `:eq`.

#### 74. Album.create inserts artists outside the album insert, with no transaction and no handling of create errors

`lib/premiere_ecoute/discography/album.ex:115` · data · correctness · plausible

Two concurrent enrich or prepare jobs create the same new artist. One gets `{:error, changeset}`, `elem(_, 1)` passes that changeset to `put_assoc`, and the album insert fails or raises. If the album insert fails for another reason (a provider_ids unique race), the artists it just created are left behind with no album.

**Fix.** Wrap artist and album creation in `Repo.transact/1`. Create artists with `Repo.insert(..., on_conflict: :nothing, conflict_target: :name)` followed by a re-select, and handle `{:error, _}` explicitly. Do the same for Album and Single `create_if_not_exists` by relying on the provider_ids unique indexes with `on_conflict`.

*Verifier:* Album.create calls Artist.create_if_not_exists, a check-then-insert against a unique index on name, before the album insert and outside any transaction, and elem(_, 1) passes an error changeset into put_assoc. That requires a concurrent race on the same new artist name, which is rare. The failure mode is an {:error, changeset} from the album insert. An orphan artist is a harmless catalog row. The race is possible, but I could not show it happening.

#### 75. The !vote chat command runs CAST(value AS FLOAT) on text votes and raises for smash/pass sessions

`lib/premiere_ecoute/sessions/scores/vote.ex:92` · data · correctness · confirmed

During a 'smash-pass' session a viewer types `!vote`. Postgres returns `invalid input syntax for type double precision: "smash"`, Postgrex raises inside the command handler, and the viewer gets no reply while the error is logged on every use.

**Fix.** Branch on the vote mode. For text options, return the most frequent value, or filter with `where: fragment("? ~ '^[0-9]+$'", v.value)`. More generally, consider storing numeric votes in a separate integer or smallint column so aggregates don't depend on casting strings.

#### 76. FK and lookup columns with no index, including one on the per-request user token preload

`priv/repo/migrations/20250626141321_create_users_oauth_tokens.exs:13` · data · performance · confirmed

As these tables grow, album, single and artist pages and every user preload scan the whole table. Deleting an album, single or artist (the admin album delete exists) must seq-scan wantlist_items and listening_sessions to check or cascade the FKs.

**Fix.** Add plain btree indexes on these columns in one migration using `create index(..., concurrently: true)` with `@disable_ddl_transaction true` and `@disable_migration_lock true`. Consider a composite `listening_sessions(user_id, status)` for `get_active_session`/`current_session`.

#### 77. Billboard generation aborts entirely on one unavailable playlist, one track without a release date, or an empty track set

`lib/premiere_ecoute/billboards/services/billboard_creation.ex:81` · domains · correctness · confirmed

One viewer submits a playlist that is later made private or deleted, or contains a local file or podcast episode with no release date. The streamer's whole billboard computation fails with an opaque error and no indication of which submission caused it.

**Fix.** Treat per-playlist fetch errors as skipped (and report them to the caller), group nil release dates under an "unknown" bucket, guard empty lists, and remove the blanket rescue so real bugs are not hidden.

#### 78. Goal balance recomputed and stored from a transaction snapshot: concurrent donations or refunds lose updates; currency conversion goes through floats

`lib/premiere_ecoute/donations/services/donations.ex:153` · domains · concurrency · confirmed

Two BuyMeACoffee webhooks arrive together. Transaction A inserts donation A and computes a balance that cannot see B's uncommitted row, and B does the same. Whichever commits last overwrites `goals.balance` with a total missing the other donation, and the cached balance stays wrong until the next donation. Converted amounts can also persist float artefacts such as 12.340000000000002.

**Fix.** Lock the goal row first (`from(g in Goal, where: g.id == ^id, lock: "FOR UPDATE")`) before recomputing, or compute the balance on read with a SQL SUM instead of caching it. Convert with `Decimal.from_float/1 |> Decimal.round(2)`, or have the Frankfurter client return a Decimal.

#### 79. Every recurring automation run creates a notification; unread notifications are never pruned and list_unread is unbounded

`lib/premiere_ecoute/notifications/notification.ex:80` · domains · performance · confirmed

An hourly automation left running for three months produces about 2,200 unread notifications. NotificationsComponent loads all of them on every LiveView mount. Notification links point to `?run=<id>` for automation_runs that HistoryPrunerWorker deleted after 30 days.

**Fix.** Limit `list_unread` (e.g. 50) and use `unread_count` for the badge. Prune unread notifications after a longer TTL, and notify on success only when the user opts in (or on state change failure to success).

#### 80. Twitch.create_history/delete_history are dead and would crash if called

`lib/premiere_ecoute/twitch.ex:16` · domains · maintainability · confirmed

Anyone who wires these functions up for ownership-scoped storage, which the history finding above needs, gets an immediate crash, or ArgumentError for an unknown application when `:files` is unset.

**Fix.** Delete these functions and the Filesystem adapter, or fix them (`to_string(user.id)`, a correct app name) and use them as the single owner-scoped storage path for history uploads.

#### 81. Real-looking OpenAI project key committed in a public workflow file

`.github/workflows/pr-app.yml:135` · quality · security · plausible

If this was ever a real key, it has been public in git history and is being abused. If it is fake, secret scanners (GitHub push protection, gitleaks) will keep flagging it and teach people to ignore alerts.

**Fix.** Confirm the key is revoked in the OpenAI dashboard and replace it with `OPENAI_API_KEY: fake_openai_key`.

*Verifier:* pr-app.yml:135 does contain a sk-proj- style literal while the other values are obviously fake. Nothing in the repo shows whether it was ever a real key. It still should be rotated or replaced with an obvious placeholder.

#### 82. Dockerfile is stale and cannot build the project

`Dockerfile:14` · quality · ops · confirmed

Someone uses the Dockerfile for a disaster-recovery rebuild or a Fly deploy (rel/env.sh.eex still has a FLY_APP_NAME branch). `mix compile` aborts with Mix.ElixirVersionError, because the project requires ~> 1.20.

**Fix.** Either delete the Dockerfile and the Fly branch in rel/env.sh.eex, or bump them to 1.20.4/29.1.1 and add a `docker build` smoke job to CI so they stay in sync.

#### 83. Coverage reports exclude the whole web layer

`coveralls.json:10` · quality · testing · confirmed

Coverage numbers look healthy while security-critical code paths go untested, for example the GET-with-approved=true path in AuthorizeController. Nothing in the coverage metric signals the gap.

**Fix.** Remove `lib/premiere_ecoute_web` from skip_files. If needed, exclude only generated or pure-template modules such as storybook and components.

#### 84. test/support (fixtures, CaseTemplates, ApiMock) is compiled into the production release; module conflicts are silenced

`mix.exs:79` · quality · architecture · confirmed

Fixture helpers that create users and data can be called from the prod remote console or any eval surface. Test-only code also becomes part of the prod compile graph, so a test helper that uses a test-only dep outside a `quote` breaks the prod build. With ignore_module_conflict, a copy-pasted module in lib silently replaces another depending on compile order, with no warning.

**Fix.** Use the standard `defp elixirc_paths(:test), do: ["lib", "test/support"]` and `defp elixirc_paths(_), do: ["lib"]`. If dev needs some fixtures (seeds, storybook), move those specific modules under lib/ behind a dev-only path. Remove `ignore_module_conflict: true`.

#### 85. Broadway pipeline tests rely on fixed sleeps, and their negative assertions pass without proving anything

`test/premiere_ecoute/sessions/scores/message_pipeline_test.exs:94` · quality · testing · plausible

A regression makes the pipeline accept invalid messages such as "11" or "-1" as votes. On a loaded CI runner the batch (timeout 50ms in test.exs:12) has not flushed within 100ms, so `Vote.all` is empty and the negative test still passes. The positive tests have the opposite problem: they fail at random when the runner is slow.

**Fix.** Make the pipelines observable. Emit telemetry or a PubSub message in `handle_batch`, or send to a test pid, and `assert_receive` on it with a timeout. For negative cases, publish a valid sentinel message after the invalid ones, wait until it is processed, then assert that only the sentinel was persisted.

*Verifier:* message_pipeline_test.exs:94 does publish, sleep 100ms, then asserts empty, which cannot tell a slow flush apart from a correct rejection. admin_broadcast_live_test.exs:54 sleeps after render_submit has already returned html, so that sleep is dead. This weakens the tests but is not a demonstrated escaped bug. Low or medium is reasonable.

#### 86. API tokens stored in plaintext and never expire

`lib/premiere_ecoute/accounts/user/token.ex:257` · security · security · confirmed

Any read access to the DB (backup leak, SQL console, a replica, a log of a failed insert) yields usable bearer credentials for every user's REST and MCP access. Those credentials stay valid until manually revoked.

**Fix.** Store `:crypto.hash(:sha256, token)` and look up by hash, as `build_hashed_token` already does. Add an optional expiry and a `last_used_at` column, and consider a recognizable prefix for secret scanning.

#### 87. Image proxy caches any 200 response from allowlisted hosts forever, served with upstream content-type

`lib/premiere_ecoute_web/controllers/images/image_proxy_controller.ex:66` · security · security · plausible

An unauthenticated client requests `/img?url=https://api.deezer.com/search?q=<random>` in a loop. Every unique URL returns 200 JSON, which is written to the cache dir forever and eventually fills the disk. Non-image content is served from the app origin.

**Fix.** Remove api.deezer.com from the allowlist, or restrict paths. Set `redirect: false` (or re-validate each hop), require an `image/*` content-type, cap body size, and bound or evict the cache.

*Verifier:* Partly wrong. Req decodes JSON responses into maps by default, so for api.deezer.com JSON File.write!(path, map) raises, giving a 500 with nothing cached. The 'caches JSON forever' scenario is therefore refuted. Disk growth is still possible through cache-busting query strings on real image hosts (e.g. i.scdn.co/image/<id>?x=N returns 200 images), each keyed by md5(url) with no size cap. The redirect-follow claim is correct but low impact, since the first hop must be allowlisted.

#### 88. Ending impersonation leaves the target user's session token valid in the DB

`lib/premiere_ecoute_web/user_auth.ex:99` · security · security · confirmed

Each impersonation leaves a live 14-day session token for the target user in user_tokens. Anyone holding a copy of the admin's old cookie, which is signed but not encrypted, can keep acting as the target after impersonation has 'ended'.

**Fix.** In end_impersonation, read `:impersonated_token` and delete it from the DB before removing it from the session. Consider a short-lived dedicated context such as "impersonation" with a much shorter validity.

#### 89. Complete in collections is neither idempotent nor atomic, and retries duplicate playlist items

`lib/premiere_ecoute/collections/collection_session/command_handler.ex:195` · sessions · correctness · confirmed

`remove_playlist_items` fails (e.g. a Spotify 5xx). The streamer clicks Complete again, and every kept track is added to the destination playlist a second time. If the node restarted during the session, the Cachex entry is gone, `rewards` is `[]`, and the Twitch channel-point rewards created at start are never deleted.

**Fix.** Mark completion first, e.g. `status: :completing`, and persist the reward ids on the CollectionSession row instead of only in Cachex. Make the Spotify sync idempotent (diff against the destination's current items) or record per-step progress so a retry resumes where it stopped.

#### 90. DecideTrack advances current_index without checking which track it was called for

`lib/premiere_ecoute/collections/collection_session/command_handler.ex:96` · sessions · concurrency · plausible

The streamer double-clicks Keep, or the LiveView and the REST API (`api/collection/dashboard_controller.ex:168`) decide at about the same time. Both commands carry the same track_id: it is appended to `kept` twice, `current_index` moves forward by 2, and the next track is skipped without ever being decided. Separately, for an API duel with `decision: :rejected`, the TrackDecided event reports the loser as `:kept`, which schedules enrichment for the wrong track.

**Fix.** Pass the expected index in the command and do a conditional update (`WHERE id = ? AND current_index = ?`, i.e. optimistic locking), returning `{:error, :stale}` on mismatch. Fix the duel event so it emits the winner's id.

*Verifier:* DecideTrack does not check track_id against the index or lock the row, so a truly concurrent LiveView plus API decide could append the same track twice and skip one. The LiveView double-click scenario does not hold: events are serial, and assigns.session is updated after apply and refreshed on :track_decided. The duel mislabel is unreachable: the API passes mode nil, so duel_track_id is always nil, and the LiveView duel always sends decision: :kept. The `:rejected`→`:kept` branch never runs.

#### 91. SkipNextTrackListeningSession has no :free clause, so the API crashes for free sessions

`lib/premiere_ecoute/sessions/listening_session/command_handler.ex:344` · sessions · correctness · confirmed

A streamer with a free session calls `POST /api/.../next`, or `POST /api/.../start`, which runs SkipNext right after a successful Start. The result is a FunctionClauseError and an HTTP 500. In the `start` case the session has already been set to active.

**Fix.** Add `def handle(%SkipNextTrackListeningSession{source: :free, session_id: id}), do: {:ok, ListeningSession.get(id), []}`, the same as the :track and :clip clauses.

#### 92. `!vote` chat command crashes in text-mode sessions (CAST to FLOAT)

`lib/premiere_ecoute/sessions/scores/vote.ex:91` · sessions · correctness · confirmed

In a smash-pass session a viewer types `!vote`. Postgres raises `invalid input syntax for type double precision: "smash"`, so the command handler crashes and the viewer gets no reply.

**Fix.** Branch on vote mode: numeric sessions keep the average, text sessions return the viewer's most frequent choice or vote count. Or filter with `v.value ~ '^[0-9]+$'` before casting.

#### 93. Unhandled params crash LiveViews (String.to_integer / to_existing_atom / Integer.parse on client input)

`lib/premiere_ecoute_web/live/admin/admin_users_live.ex:34` · web · correctness · confirmed

`/admin/users?page=abc` raises ArgumentError, giving a 500 on the dead render. A tampered `set_round_mode` with `mode="foo"` (or an existing atom like `"ok"`) either crashes the collection LiveView mid-session or stores a nonsense round mode. The crash resets its assigns, such as the unsaved tracklist order. This is not an atom-exhaustion risk, because only existing atoms are used.

**Fix.** Whitelist enum params with a small `parse_mode/1` using function-head matching (`"streamer_choice" -> :streamer_choice; _ -> default`). Use `Integer.parse` with a default for pagination. Validate `visibility` through the changeset's `Ecto.Enum` cast instead of converting to an atom first.

#### 94. Direct Repo calls in LiveViews (coding-standards violation)

`lib/premiere_ecoute_web/live/admin/donations/goal_live.ex:70` · web · architecture · confirmed

Preload shapes are duplicated across handlers and drift from the context API. For example, SessionLive preloads `report.votes`, then ignores them and calls `Report.generate`, which reloads the votes itself, so the same data is loaded twice.

**Fix.** Add context functions such as `Donations.get_goal_with_entries/1`, `Accounts.get_user_with_providers!/1` and `Sessions.get_session_for_page/1`, and remove the `alias PremiereEcoute.Repo` from web modules. Boundary exports could enforce this.

#### 95. Raw styled buttons bypass <.button> and theme tokens

`lib/premiere_ecoute_web/live/playlists/playlist_live.html.heex:34` · web · ux · confirmed

The hard-coded gray/green/red Tailwind colours ignore the daisyUI theme, so these buttons look wrong after the recent warm-violet or light theme changes. Behaviour such as disabled and loading states differs from `<.button>`.

**Fix.** Migrate action buttons to `<.button variant=...>` gradually, starting with playlist_live, session_live, collection_session_live and history_view_live, which have the most raw buttons. Keep raw `<button>` only for toggles and segmented controls, as the guide allows.

#### 96. Dashboard catch-all handle_event and arbitrary option keys

`lib/premiere_ecoute_web/live/sessions/dashboard_live.ex:178` · web · maintainability · confirmed

A typo in a template's `phx-click` name produces a user-facing "Received event: …" flash instead of failing loudly in tests. Arbitrary `flag` values accumulate as junk keys in `listening_session.options`, which later code reads with `options["..."]`.

**Fix.** Whitelist the toggleable flags, for example `when flag in ~w(autostart ...)`. Replace the catch-all with a `Logger.warning` and no flash, or remove it so tests catch the unmatched event.

#### 97. Low LiveView test coverage on the risky paths

`test/premiere_ecoute_web/live/sessions/session_live_test.exs:1` · web · testing · confirmed

All three high-severity issues above sit in untested handlers and would not be caught by `mix test`.

**Fix.** Add focused LiveView tests that push crafted events with `render_submit`/`render_click` and extra params (review `user_id`/`role`, post-vote `note: "abc"`), plus a HistoryLive upload test with a malicious RequestID.

## Refuted

- **async: true tests mutate global Application env** (quality): The only other reader of :twitch_extension_secret, widget_controller_test.exs, is async: false. ExUnit runs sync modules after all async ones, so they never run at the same time, and both files set the same value and restore the original. The Seaweed config is read only by the Seaweed adapter, and seaweed_test.exs is the only test that uses it. Other podcast tests go through the Storage adapter config, which is a different key. No real race is reachable today.
