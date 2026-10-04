---
name: browse
description: Navigate the local Premiere Ecoute app in a real browser (Playwright) as a chosen user, with screenshots, text snapshots and videos with a visible cursor. Use to see, click through or record a UI change in the running dev app.
---

# Browse the local app

Playwright drives system Chrome headless against `http://localhost:4000`. Tidewave's `browser_eval` is not an option (it needs a paid Tidewave login); Tidewave's `project_eval`, `execute_sql_query` and `get_logs` still work and are the way to check server state.

## Prerequisites

- App running as a named node: `iex --sname dev -S mix` (node `dev@<short hostname>`; override with `PW_NODE`). Check with `epmd -names`.
- `npm install` once in this directory.

## Workflow

All commands run from `.claude/skills/browse/`. Output goes to `.out/` (gitignored).

```bash
node login.mjs <username>                      # session cookies -> .out/state.<username>.json
node tour.mjs <username> /sessions /wantlist   # screenshot + ARIA text per page, one video, page errors
./frames.sh .out/tour-*/page@*.webm 2          # video -> frames; Read the PNGs to "watch" it
```

Read the `*.png` with `Read`. Navigate with the `*.aria.txt` snapshot (cheaper than HTML). For custom flows, write a script that imports `launch`/`statePath` from `browser.mjs` and `installCursor`/`glideClick` from `cursor.mjs`.

## How login works

`login-token.exs` calls `Accounts.deliver_login_instructions/2` on the running dev node over Erlang RPC. The app never emails the magic link; it stores a hashed token and returns the raw one, so `/mailbox` stays empty. `login.mjs` opens `/users/log-in/<token>` and clicks "Log in". Works for any existing user, no password. It aborts unless the node reports `Mix.env() == :dev` and `PW_BASE` is local. Each login inserts one `user_tokens` row.

## Rules

- Read the `handle_event` before clicking anything that is not plain navigation. Toggles such as "Display votes" write to `listening_session.options` in the dev DB.
- Do not start sessions, trigger playback or hit Spotify/Twitch actions without asking. A user with Spotify linked acts on a real account.
- `.out/` holds live session cookies and traces with request bodies. Do not commit or share it.

## Gotchas

- Wait for `.phx-connected` before clicking, or the click fires before the LiveView socket is up and does nothing.
- Spotify-gated pages (`/sessions/:token/dashboard`) redirect to `/sessions` with "Session not found or connect to Spotify" for users without Spotify tokens. Check `user_oauth_tokens` (`provider = 'spotify'`, match on `parent_id`).
- Login page is `/users/log-in`, not `/log-in`.
- Use `exact: true` on `getByRole` names: "Retro" also matches the sidebar's "Retrospective".
- Console errors on every dev page (PostHog, `live_reload` iframe) are CSP noise, not bugs.
- `fullPage` screenshots during `recordVideo` can leave grey letterboxing in video frames.
- Headless Chrome does not render the OS cursor; `installCursor` draws one so videos show where clicks land.
