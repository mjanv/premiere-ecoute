# Manual deploy

Fallback when CI is unavailable. Requires explicit user approval. Bypasses the automatic backup and `/health` rollback unless you use `deploy.sh`, so verify by hand afterwards.

## Option 1: `deploy.sh` (preferred)

Needs a filled `.env.production` (copy from `.env.production.example`; values are the same as the GitHub Secrets, see [secrets.md](secrets.md)).

```bash
cd apps/digital_ocean
./deploy.sh
```

It builds the release (`MIX_ENV=prod mix release`), copies it to `/opt/premiere-ecoute`, installs `.env` plus the systemd and Traefik files, and restarts `premiere-ecoute`. Migrations run via `ExecStartPre`.

## Option 2: step by step

```bash
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release --overwrite

rsync -avz --delete --exclude='.env' \
  _build/prod/rel/premiere_ecoute/ root@68.183.219.251:/opt/premiere-ecoute/

ssh root@68.183.219.251 'systemctl restart premiere-ecoute'
```

`--delete` removes files on the droplet not in the build. Do not drop the `--exclude='.env'`.

## Then verify

`curl -fsS https://premiere-ecoute.fr/health`, `systemctl status premiere-ecoute --no-pager`, and a log tail for startup or migration errors.
