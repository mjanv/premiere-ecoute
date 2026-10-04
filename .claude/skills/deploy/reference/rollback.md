# Rollback

## Preferred: revert and redeploy

```bash
git revert <bad-commit>   # on main
git push                  # CI redeploys
```

Slower than restoring a backup, but traceable and uses the tested path.

## Fast: restore the pre-deploy backup on the droplet

CI backs up the running release on the droplet before each sync. The backup location is **not documented**: read `.github/workflows/release-app.yml` (the backup and rollback steps) to find the path, then confirm with the user before restoring.

Steps once the path is known: stop nothing yet; sync the backup back over `/opt/premiere-ecoute/` (keep `.env`), `systemctl restart premiere-ecoute`, verify `/health`.

## Database

Rolling back code does not roll back migrations. If the bad release ran a destructive or incompatible migration, stop and restore from backup (`docs/guides/backup.md`) only with explicit user approval.
