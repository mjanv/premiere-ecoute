---
name: deploy
description: Deploy, inspect, or roll back Premiere Ecoute production (Digital Ocean droplet). Use when the user asks to deploy, ship, check prod status, read prod logs, restart a service, or roll back.
---

# Deploy

Production is one Digital Ocean droplet (`root@68.183.219.251`, domain `premiere-ecoute.fr`). Phoenix runs as a native release under systemd (`premiere-ecoute`, port 4000), behind Traefik (80/443), with local PostgreSQL.

```
Internet → Traefik (80/443) → Phoenix (4000, systemd) → PostgreSQL (localhost)
```

## Rules

- **Never deploy on your own.** The user pushes to `main`; you check and monitor.
- Read-only commands: run freely. State-changing commands: ask first, every time.
- Never print secret values from `.env` or GitHub Secrets.
- If the task does not match the flows below, stop and ask.

## Deploy (default: CI)

Push to `main` triggers `.github/workflows/release-app.yml` (also runnable from Actions → "Deploy to Production"). It builds the release, backs up the current one on the droplet, rsyncs the new one, restarts the service, then checks `/health` and rolls back automatically on failure. Migrations run via `ExecStartPre` in the systemd unit.

1. Pre-flight, before the user pushes:
   - Branch is `main`, working tree clean, up to date with `origin/main`.
   - `mix test` and `mix quality` pass.
   - New migrations are backward compatible: the old release keeps serving while the new one migrates, and rollback does not roll the DB back.
   - New env vars exist as GitHub Secrets and are wired in the workflow. See [reference/secrets.md](reference/secrets.md).
2. After the push, watch the run: `gh run list --workflow release-app.yml --limit 3`, then `gh run watch <id>`.
3. Verify (read-only):
   - `curl -fsS https://premiere-ecoute.fr/health`
   - `ssh root@68.183.219.251 'systemctl status premiere-ecoute --no-pager'`
4. Report the run result and the health check faithfully. If CI rolled back, say so and pull logs.

CI down or unusable: [reference/manual-deploy.md](reference/manual-deploy.md), only with explicit user approval.

## Inspect (read-only, no confirmation)

```bash
ssh root@68.183.219.251 'systemctl status premiere-ecoute traefik postgresql --no-pager'
ssh root@68.183.219.251 'journalctl -u premiere-ecoute -n 200 --no-pager'
ssh root@68.183.219.251 'journalctl -u premiere-ecoute -u traefik --since "30 min ago" --no-pager'
```

Never use `-f` (follow); it blocks. For error triage, prefer the `debug` skill (Sentry, Grafana, logs).

## Change state (confirm first)

| Action | Command |
|---|---|
| Restart app | `ssh root@68.183.219.251 'systemctl restart premiere-ecoute'` |
| Restart proxy | `ssh root@68.183.219.251 'systemctl restart traefik'` |
| Stop a service | `systemctl stop <unit>` (takes prod down; state the impact) |
| Firewall | `ufw ...` (never lock out port 22) |
| Manual deploy / rollback | see reference files |

After any change, re-run the verify step.

## Roll back

CI rolls back by itself when `/health` fails. For a bad release that passes health: [reference/rollback.md](reference/rollback.md). Simplest safe path is reverting the commit on `main` and letting CI redeploy.

## References

- [reference/manual-deploy.md](reference/manual-deploy.md): `deploy.sh` and rsync fallback
- [reference/rollback.md](reference/rollback.md): rollback options
- [reference/secrets.md](reference/secrets.md): required GitHub Secrets, domain change
- [reference/setup.md](reference/setup.md): first-time droplet setup, firewall, TLS
- Backups and restore: `docs/guides/backup.md`
