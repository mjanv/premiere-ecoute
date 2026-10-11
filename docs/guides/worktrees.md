# 🌳 Worktrees guide

Run several checkouts of the app side by side, one per feature or agent, without sharing a database, a port or a cookie.

## Use

Commit and push to `main` first: new worktrees branch from `origin/main` (see `worktree.baseRef` in `.claude/settings.json`).

```bash
claude --worktree feature-auth    # terminal 1
claude --worktree other-feature   # terminal 2
```

The worktree lives in `.claude/worktrees/<name>`. On start, the SessionStart hook creates its dev database (slow the first time) and points the MCP servers at its port. Then:

```bash
just info     # name, ports and suffix of this checkout
just server   # dev server, prints its address
mix test      # uses its own test database
```

Subagents: ask for "worktrees for your agents" or set `isolation: worktree` in the agent's frontmatter. They get no dev database, but `mix test` creates its own.

Clean up from the original checkout. Claude's exit prompt removes the worktree but not its databases:

```bash
just worktree-remove feature-auth
```

## What is isolated

The identity comes from `PremiereEcoute.MixProject.worktree/0` in `mix.exs`, repeated in shell by the justfile and the SessionStart hook (`just info` prints it): a linked worktree (`.git` is a file) is named after its directory, the original checkout (`.git` is a directory) has none and keeps the defaults on any branch.

| | Original checkout | Worktree `<name>` |
|---|---|---|
| Web / mock Twitch / test endpoint | 4000 / 4001 / 4002 | `4000 + 10·slot` (+0 / +1 / +2), slot hashed from the name |
| Databases | `premiere_ecoute_{dev,test}` | `premiere_ecoute_{dev,test}_<name>` |
| Erlang node | `dev` | `dev_<name>` |
| Session cookie, podcast storage keys | default | suffixed with `<name>` |

The test database also gets `MIX_TEST_PARTITION`. Override the port with `PE_PORT`, the name with `PE_WORKTREE`.

## What is shared

- `.env` and `.env.test`: copied in by `.worktreeinclude`.
- `deps/`, `assets/node_modules`, `.claude/skills/browse/node_modules`: symlinked by `worktree.symlinkDirectories`. Run `mix deps.get` only in the original checkout.
- Postgres, SeaweedFS, Prometheus and Grafana containers.

`_build/` is never shared: the worktree name is compiled in.

## Limits

- Twitch and Spotify OAuth only work on the original checkout, whose redirect URIs are registered. Elsewhere, use the `browse` skill's magic-link login with `PW_BASE=http://localhost:<port>` and `PW_NODE=dev_<name>`.
- All worktrees share one Postgres. Each test run opens `schedulers × 2` connections per repo (two repos), so a few at once exceed Postgres' default `max_connections = 100` (`FATAL 53300 too many clients already`). `docker-compose.yml` raises it to 400; after pulling that change run `docker compose up -d postgres` to recreate the container (data is kept in its volume). Check with `docker exec postgres psql -U postgres -c "show max_connections"`.
- The "database ... does not exist" errors at the start of a first `mix test` in a worktree are harmless: the alias creates the test database right after.
- Hashed ports can collide. Run `just info` and set `PE_PORT` if two worktrees share one.
- Worktrees made with plain `git worktree add` get no hook: run `mix ecto.setup` yourself.
