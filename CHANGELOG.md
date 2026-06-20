# Changelog

<!-- Last analyzed commit: c3e04540 (2026-05-30) -->

## May 2026

* [Feature] Session notes: take freeform notes during a listening session via a keyboard-driven HUD (Tab to toggle, Enter to save) — notes are automatically linked to the track playing at the time and grouped into pre/during/post-session sections.
* [Feature] Session reminder: save a persistent checklist or talking-point text in account settings, then press R during any session to open it in a modal overlay without leaving the dashboard.
* [Feature] Post-session voting: viewers who missed the live stream can now rate each track individually via a modal on the session page, as long as they haven't voted before.
* [Feature] Playlist subscriptions: viewers can subscribe to a streamer's playlist and receive email or in-app notifications when it is updated; streamers trigger notifications manually or via playlist automations.
* [Feature] Twitch channel point rewards: create, list, update, and delete custom channel point rewards and handle real-time redemption events via EventSub webhooks — including a built-in reward catalog with locale-aware presets (song request, skip track).
* [Feature] Image proxy: cover art from music provider CDNs is now cached server-side and served through a local proxy endpoint, reducing external requests and enabling long-lived browser caching.
* [Feature] Admin broadcast dashboard: admins can send chat messages or highlighted announcements to one or all streamer channels via the PremiereEcouteBot, with a live delivery log.
* [Feature] Discography enrichment from playlists: scanning a library playlist (e.g., New Music Friday) now schedules full discography enrichment for any new artists or albums found — triggerable manually from the playlist page or via automations.
* [Feature] Daily radio-to-discography sync: a nightly cron job automatically enriches the discography with artists and albums discovered from the previous day's radio tracks across all streamers.
* [Feature] Explicit content badges: albums and tracks flagged as explicit in Spotify now show an "E" badge in the session creation UI.
* [Feature] Wantlist REST API: authenticated API endpoints to fetch the user's wantlist, save the currently playing track, and remove items — enabling Stream Deck and browser extension integrations.
* [Feature] Collection session REST API: programmatic control of collection session lifecycle (start, open/close vote windows, decide track, complete session) and binary voting via API, for Stream Deck control.
* [Feature] Configurable YouTube title template: set a show name and title format in account settings (e.g. `{show_name} | {artist} – {title} | {score}`) and preview it live before exporting.
* [Improvement] Viewer home page redesigned with per-streamer cards consolidating radio, playlists, and recent sessions — with a "My last sessions" carousel at the top and a cleaner playlist subscription modal.
* [Improvement] Discography enrichment now triggers when a track is kept in a collection session, mirroring the behavior already in place for wantlist and radio saves.
* [Improvement] Session summary link sent to Twitch chat 20 seconds after a session ends, so viewers can find the retrospective without searching.
* [Improvement] Premiere Pro export time bias slider now includes ±10ms and ±100ms fine-tuning buttons with live timestamp preview, and the range is extended to 10 minutes.
* [Improvement] Premiere Pro export gains 50fps, 59.94fps, and 60fps frame rate options for European broadcasting, NTSC gaming streams, and PC/mobile recordings.
* [Improvement] SwaggerUI shows only the API endpoints relevant to the authenticated user's role (streamer, viewer, or admin).
* [Fix] Duel reminder sound now plays on every trigger — previously it silently failed on repeat triggers due to a LiveView diff optimization.
* [Fix] Stopping a session no longer crashes when Spotify fails to return the active device list, ensuring the summary link is always sent to chat.
* [Fix] Image proxy cache is now stored outside the deployment directory so it survives rsync deploys without causing 500 errors.

## April 2026

* [Feature] Viewer track submission to streamer playlists: a public submission page lets viewers search Spotify and add tracks directly to a playlist the streamer has opened for contributions — with open/close toggle and optional playlist preview.
* [Feature] Shareable session URLs: sessions are now accessible via human-readable URLs like `/sessions/username/this-music-may-contain-hope-bd45ec30` with a one-click share button.
* [Feature] Autostart option: toggle whether the first track starts automatically 1 second after session launch, or manually via a dedicated "Start First Track" button.
* [Feature] Duel reminder system for collection sessions: schedule recurring reminders at custom intervals with a countdown badge and choice of notification sound (none, ding, or Yugioh theme).
* [Feature] "Six seveeeen!" vote mode: new voting preset with options 6, 7, and 67 — a meme-friendly alternative to the standard 0-10 scale.
* [Feature] Skip voting for short tracks: configure a duration threshold (default 45s) so interludes and sound collages are silently skipped without opening a vote window.
* [Feature] Chat command settings: toggle the `!save` (wantlist) and `!vote` commands independently per streamer in account settings.
* [Feature] Delete collection sessions from the list page, with a confirmation modal to prevent accidents.
* [Feature] Admin analytics dashboard with 30-day event volume charts, KPI cards, and a top-events breakdown; new event store viewer for browsing recorded domain events.
* [Improvement] Wantlist on the radio page: add tracks directly from playback history, with automatic Spotify ingestion for tracks not yet in the local discography.
* [Improvement] Bell notifications when tracks are saved to the wantlist, from either the radio page or a `!save` chat command.
* [Improvement] Overlay widgets now scale to any OBS browser source size using viewport-relative units — no more gray borders at custom resolutions.
* [Improvement] Overlay settings page shows the recommended OBS browser source dimensions for each overlay type, updating live as the type changes.
* [Improvement] Playlist submissions now support album tracks (not only singles); duplicate detection groups by track title to catch identical songs from different sources.
* [Improvement] Playback state cache TTL now matches remaining track duration, keeping `!save` and other chat commands reliably warm.
* [Improvement] 48kHz audio capture throughout the speech-marker pipeline, matching OBS default — no resampling needed and no audio/video drift.
* [Improvement] Keyboard navigation on the retrospective carousel: left/right to step through graphs, up/down to jump to last/first.
* [Improvement] Extension API routes reorganized under `/api/extension`; `mix extension.build` task added for packaging the browser extension.
* [Improvement] Playback state shared cache introduced to reduce redundant Spotify API calls across extension polling and session handlers.
* [Fix] Radio playback tracking loop now survives transient API failures (e.g. expired token) by scheduling a 30-second retry instead of silently dying.
* [Fix] Waveform no longer disappears during track transitions — fixed crash when Spotify player has no active item between tracks.
* [Fix] Crash when accessing an overlay URL with an unknown username now returns a safe error instead of a BadMapError.
* [Fix] Album pick submission was failing due to artist field type mismatch; submission URL now uses username instead of numeric user ID.
* [Fix] Backlink navigation on the session viewer page corrected.

## March 2026

* [Feature] Wantlist: save albums, tracks, and artists to a personal collection from discography pages, the radio, and the home page — with grid/list toggle and direct links to Spotify, Deezer, and Tidal.
* [Feature] "Start First Track" button: session init and first-track playback are now two separate steps — start the session first (bot announces, Spotify configured), then choose when the music actually begins.
* [Improvement] Speech-to-text backend is now pluggable: swap between Mistral and OpenAI Whisper via config; transcriptions now display live below the waveform in the session dashboard.
* [Feature] Track enrichment with Genius: album pages now automatically find and display Genius lyrics links for each track, with fuzzy artist matching to avoid false positives.
* [Feature] Collection sessions: take two playlists and build a new one by choosing between pairs of tracks — using streamer choice, audience vote (1 vs 2 in chat), or head-to-head track duels. Perfect for building "best of" or festival playlists collaboratively.
* [Feature] Speech markers: the browser microphone detects when you are speaking during a session. Each detected speech segment is timestamped and can be exported as an Adobe Premiere Pro XMEML file for automatic video chapter markers in your recording.
* [Feature] Wikipedia drawer: click any artist or album name in the session to see a Wikipedia summary with thumbnail, without leaving the page. Artist names in collection sessions are now clickable too.
* [Feature] Playlist automations: create rules that automatically run on your playlists on a schedule or on demand (create new playlist, empty playlist, remove duplicates), with in-app notifications when they succeed or fail.
* [Feature] Tidal music provider added: album pages now automatically enrich themselves with links to Spotify, Deezer, Tidal, and Wikipedia in the background.
* [Feature] YouTube Music, Genius, and MusicBrainz APIs integrated for music metadata enrichment.
* [Feature] Stream Deck plugins split into two separate distributions: a streamer plugin (full session control) and a viewer plugin (vote-only), with automated GitHub release workflow.
* [Feature] New homepage showing recent listening sessions, ongoing sessions, and radio status with manual start/stop.
* [Feature] Dedicated retrospective page per album/session: track scores, streamer/viewer notes, replay links (YouTube/podcast), and a like/review system for viewers.
* [Feature] Viewer home page: a dedicated landing page showing active sessions they can participate in and their voting history.
* [Feature] Artist pages, single-track detail pages, and users listing page added to the discography section.
* [Feature] Mistral AI integration: chat completions, content moderation, and French audio transcription via Mistral API, alongside existing OpenAI/Whisper support.
* [Feature] Single-track listening sessions: start a session on just one Spotify track (not a full album), useful for reviewing or voting on a specific song.
* [Feature] Playlist sessions: browse forward/backward through a playlist with full voting support per track.
* [Feature] Random album pick pool: build a curated pool of albums (added by streamer or submitted by viewers), then spin a wheel to randomly pick one for the next listening session.
* [Feature] Duel mode now includes 'Pick both' button to keep both tracks A and B in collection sessions, with button gradient using profile primary/secondary colors.
* [Improvement] Homepage redesigned with two direct Twitch login buttons ("Streamer with Twitch" / "Viewer with Twitch") — no intermediate role-selection step.
* [Improvement] Session dashboard redesigned: Premiere Pro export button with official Adobe logo, "View Retrospective" with sparkles icon, visibility control integrated as compact split-button.
* [Improvement] Collection session refactored to use PlayerSupervisor for playback control, with player state bar showing device, artist-track, progress timer, and playback toggle.
* [Improvement] Wikipedia drawer enhanced with table of contents navigation.
* [Improvement] Handler registry optimized from O(n) to O(1) lookup using persistent_term caching, improving command/event bus performance.
* [Improvement] Oban upgraded to v14 with improved message pipeline batching (timeout increased to 1000ms for stability).
* [Fix] OAuth flash issue fixed: misleading "We can't find the internet" error no longer appears during successful Twitch redirect.
* [Fix] Artist field now correctly populated in album search results.
* [Fix] Collection overlay route now accepts username as parameter.

## February 2026

* [Feature] Radio page: every track played on Spotify during a stream is automatically recorded with timestamp. Viewers visit `/radio/:username` to see what music was played during recent streams — like "C'était quoi ce titre?" on Radio Nova.
* [Feature] Radio starts and stops automatically when the streamer goes live or ends their stream on Twitch.
* [Feature] OBS overlay colors are now fully customizable per streamer: pick a primary and secondary color in account settings to match your stream's visual identity. The overlay adapts background, text, and progress bar colors based on vote state.
* [Feature] Stream Deck plugin (working demo): control your listening session directly from a Stream Deck — start/stop, skip tracks, vote — without touching the browser.
* [Feature] REST API with long-lived bearer tokens introduced for Stream Deck and external integrations.
* [Feature] "My Tops" page at `/retrospective/tops`: your highest-voted tracks ranked by score, filterable by all-time, year, or month.
* [Feature] YouTube export enhanced with configurable sections: title, intro text, viewer/streamer scores, and chapter timestamps can each be toggled independently.
* [Feature] Individual track lookup and track search added for Spotify and Deezer.
* [Fix] Spotify API rate limiting (429 errors) now handled gracefully: the page stays interactive, a rate limit banner appears automatically, and the player auto-stops after 3 hours if a page is left open.
* [Fix] Cache contents (OAuth tokens, Twitch subscriptions) now persisted to disk across server restarts, eliminating re-authentication after deployments.
* [Fix] Short tracks (under 60 seconds) now handled correctly: vote window opens at 5 seconds in, and "votes closing soon" warning is skipped.
* [Fix] Spotify player polling edge cases for short tracks resolved.
* [Fix] Twitch EventSub unsubscription properly implemented — no dangling webhook subscriptions after sessions end.
* [Fix] Nil playlist guard and ArgumentError in session summary handler fixed.
* [Removed] Tidal API removed (replaced with more complete Tidal integration in March).

## January 2026

*(No commits in this period — development paused.)*

## December 2025

* [Feature] Twitch Story: import your Twitch data export to explore your full viewing history — ads watched, bits and subscriptions, chat message archive, minutes watched by game, and follower history — all visualized with interactive charts.

## November 2025

* [Feature] `!vote` chat command: viewers type `!vote` during a session to receive their personal average score as a bot reply in chat.
* [Feature] Twitch chat command system: messages starting with `!` are detected, parsed, and handled by a dedicated command handler (extensible for future commands).
* [Feature] Track timestamps recorded automatically during sessions; export them as YouTube chapter markers with an adjustable time bias slider.
* [Feature] `!premiere` chat command: sends a welcome/info message in chat.
* [Feature] Sidebar navigation can now be collapsed to save screen space.
* [Feature] Oban background job monitoring dashboard available for administrators at `/oban`.
* [Feature] Stream online/offline detection via Twitch EventSub: the platform knows when a streamer goes live or ends their stream.
* [Feature] Spotify shuffle and repeat modes are automatically disabled at the start of every listening session.
* [Fix] Double-session bug fixed: two open session pages can no longer trigger duplicate track skips simultaneously — background job uniqueness constraints prevent this.
* [Fix] Spotify player errors (including API rate limits) are now displayed clearly and the player restarts automatically after failures.
* [Improvement] Bot messages sent asynchronously — the session dashboard is no longer blocked while messages are delivered.
* [Improvement] Twitch message rate limiting properly respected with a circuit breaker — messages are queued and retried without loss.

## October 2025

* [Feature] Only one active listening session allowed per streamer at a time — a clear error is shown if a second is attempted.
* [Feature] OBS overlay links are now session-independent — they always show the streamer's current active session. Create a fixed OBS scene without updating the link between sessions.
* [Feature] Bot announces in Twitch chat 30 seconds before votes close so viewers know when to cast their final vote.
* [Feature] Retrospective visibility controls: set a session retrospective to private, protected (authenticated users only), or public (anyone with the link).
* [Feature] BuyMeACoffee donation webhooks integrated: new donations and refunds are recorded and attributed to fundraising goals automatically.
* [Feature] Donation tracking system: fundraising goals, donation records, and expenses with admin management pages and a stream overlay for real-time donation display.
* [Feature] Twitch browser extension proof-of-concept: viewers can save any currently-playing track on a stream to a predefined Spotify playlist.
* [Feature] CI/CD pipeline added with automated quality checks and unit tests via GitHub Actions.
* [Improvement] Chat messages from the bot are now sent in the streamer's preferred language (French, English, or Italian).
* [Improvement] Track announcements show their position within the album, e.g., "(3/12) Song Name".

## September 2025

* [Feature] Voting windows open automatically 30 seconds (configurable) after each track starts and close when tracks change — no manual management needed.
* [Feature] Overlays show live per-track scores in real time; vote results are only displayed while voting is open.
* [Feature] Auto-advance timer: the session skips to the next track automatically after a configurable countdown (0–60 seconds), with a real-time visual countdown.
* [Feature] Auto-dismiss flash messages: notifications disappear after 10 seconds with a fade-out animation.
* [Feature] Create playlists and filter library entries for duplicates directly from the library management page.
* [Feature] Festival poster creation: streamers can build a graphical poster from multiple playlists for festival events.
* [Feature] Session display settings (vote visibility, next track timer) are now saved and restored automatically between sessions.
* [Improvement] Overlay templates extracted into modular components (single, double, player); session list paginated with infinite scroll.
* [Improvement] Modal system rewritten as client-side JavaScript — modals open and close without server round trips, with animated transitions and keyboard navigation.

## August 2025

* [Feature] **Release 1.0** — first live public test with Flonflon's Twitch community on the Sabrina Carpenter album.
* [Feature] New player overlay mode for OBS: full 1200px-wide layout showing album art, track info, progress bar, and live viewer/streamer scores.
* [Feature] Retrospective "My Votes" page at `/retrospective/votes`: browse your full vote history by time period with album detail modals.
* [Feature] Session retrospective page: view all track scores for a completed session with vote trend analysis.
* [Feature] Billboard feature: analyze multiple Spotify and Deezer playlists to generate a ranked track list by frequency, with a visual top-3 podium, artist grouping view, and interactive detail modals.
* [Feature] Billboard submissions: viewers submit playlist URLs via a public link, with self-service deletion using unique tokens; admin review and search/filter of submissions.
* [Feature] Export a billboard's top tracks directly to a Spotify playlist.
* [Feature] Home dashboard for authenticated users: view active sessions, recent albums, and manage your playlist library.
* [Feature] Feature flag system for per-user and per-role feature rollout.
* [Feature] GDPR consent management flow added at registration.
* [Feature] Deezer API integration as a second music provider alongside Spotify.
* [Feature] Twilio SMS webhook endpoint added.
* [Improvement] Frontend CSS reorganized into a modular design system; JavaScript hooks extracted into individual modules; Storybook component library set up.
* [Fix] Spotify album search dropdown now closes automatically when an album is selected.
* [Fix] Vote message parsing corrected to avoid processing invalid votes.

## July 2025

* [Feature] Twitch bot chat messages added for session start, track changes, and vote announcements using a dedicated PremiereEcouteBot account.
* [Feature] React Native mobile viewer app introduced, connected via Phoenix WebSocket channels.
* [Feature] Vote score graph visualization for tracking scores across all tracks in a session.
* [Feature] Followers page: see who follows you on the platform.
* [Feature] Admin dashboard with user management, impersonation, and event store browsing.
* [Feature] French and Italian internationalization (i18n) added to all UI text.
* [Feature] Prometheus/PromEx observability metrics integrated.
* [Feature] Legal pages (cookies, privacy policy) added.
* [Feature] Oban background job processing integrated for all async tasks.
* [Feature] Documentation site generated with ExDoc and published via GitHub Actions.

## June 2025

* [Feature] **Initial launch**: Twitch-only authentication, Spotify album search and playback control, per-track voting via Twitch chat, a dark-themed streaming dashboard, and a real-time OBS overlay showing live scores — all built on a command/event bus architecture.
