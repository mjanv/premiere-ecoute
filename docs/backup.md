# Database Backup & Restore

This document covers backing up and restoring the production PostgreSQL database
(`premiere_ecoute_prod`) on the Digital Ocean droplet (`68.183.219.251`). See the
[deployment guide](deployment.md) for general deployment/infrastructure context.

## Automated Daily Backup (GitHub Actions)

`.github/workflows/backup-db.yml` runs daily at 03:00 UTC (and on manual `workflow_dispatch`),
storing the dump as a GitHub Actions artifact — free and unlimited in size on this public repo.
No new accounts or secrets beyond what the deploy workflow already uses.

Steps:

1. SSHes into the droplet (reuses `DO_SSH_PRIVATE_KEY` + `DO_HOST` from the deploy workflow)
2. Runs `pg_dump -Fc` (custom format, for use with `pg_restore`) on the droplet
3. Copies the dump back to the runner and uploads it as the `postgres-backup` artifact
4. Cleans up the temporary dump on both the droplet and the runner
5. Only once the new artifact is confirmed uploaded, deletes any older `postgres-backup`
   artifacts — so the previous backup is never removed before a new one safely exists

The artifact's `retention-days` is set low (2 days) as a safety net only — it's not the primary
cleanup mechanism, since the workflow deletes older artifacts explicitly after each successful
run. Only the latest daily dump is ever retained.

### Manual trigger

Run on demand from **Actions → Backup Production Database → Run workflow**, or:

```bash
gh workflow run backup-db.yml --repo mjanv/premiere-ecoute
```

## Restoring from the automated backup

> **Destructive operation.** This drops and recreates the entire production database before
> restoring. Only run this deliberately, when you actually need to restore.

**1. Download the backup artifact** (requires the `gh` CLI, authenticated):

```bash
gh run download --repo mjanv/premiere-ecoute --name postgres-backup
```

This pulls the most recent `postgres-backup` artifact into your current directory as
`premiere_ecoute_prod_YYYYMMDD_HHMMSS.dump`. Only the latest is kept — the workflow deletes
older ones after each successful run (see above) — so this always gives you the most recent
daily backup, not an older point in time. If you need a specific past run before it's rotated
out, list runs first:

```bash
gh run list --repo mjanv/premiere-ecoute --workflow=backup-db.yml
gh run download <run-id> --repo mjanv/premiere-ecoute --name postgres-backup
```

**2. Copy the dump to the droplet:**

```bash
scp premiere_ecoute_prod_*.dump root@68.183.219.251:/tmp/restore.dump
```

**3. Stop the app, drop/recreate the database, restore, restart:**

```bash
ssh root@68.183.219.251 'systemctl stop premiere-ecoute && \
  sudo -u postgres dropdb premiere_ecoute_prod && \
  sudo -u postgres createdb premiere_ecoute_prod && \
  sudo -u postgres pg_restore -d premiere_ecoute_prod /tmp/restore.dump && \
  systemctl start premiere-ecoute'
```

**4. Clean up the remote temp file and verify:**

```bash
ssh root@68.183.219.251 'rm -f /tmp/restore.dump'
ssh root@68.183.219.251 'systemctl status premiere-ecoute --no-pager'
```

Note: this dump is produced with `pg_dump -Fc` (custom format), so it must be restored with
`pg_restore` — not `psql`. That's different from the manual `backup.sh`/`restore.sh` scripts
below, which use plain SQL and `psql`.

## Manual Backup (script)

Using the provided backup script:

```bash
cd apps/digital_ocean
./backup.sh
```

This creates a timestamped backup in `backups/premiere_ecoute_prod_YYYYMMDD_HHMMSS.sql.gz`.

Or manually:

```bash
ssh root@68.183.219.251 'sudo -u postgres pg_dump premiere_ecoute_prod | gzip' > backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

## Manual Restore (script)

Using the provided restore script:

```bash
cd apps/digital_ocean
./restore.sh backups/premiere_ecoute_prod_YYYYMMDD_HHMMSS.sql.gz
```

Or manually:

```bash
scp backup.sql.gz root@68.183.219.251:/tmp/
ssh root@68.183.219.251 'systemctl stop premiere-ecoute && \
  sudo -u postgres dropdb premiere_ecoute_prod && \
  sudo -u postgres createdb premiere_ecoute_prod && \
  gunzip -c /tmp/backup.sql.gz | sudo -u postgres psql premiere_ecoute_prod && \
  systemctl start premiere-ecoute'
```
