# First-time droplet setup

Only for a fresh Ubuntu droplet. Run once, with user approval.

```bash
apps/digital_ocean/setup.sh
```

Installs PostgreSQL and Traefik, creates system users, configures UFW. Then:

1. Create the deploy SSH key and install it on the droplet:
   ```bash
   ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/premiere_ecoute_deploy
   ssh-copy-id -i ~/.ssh/premiere_ecoute_deploy.pub root@68.183.219.251
   ```
   Store the private key as the `DO_SSH_PRIVATE_KEY` secret.
2. Add the other secrets ([secrets.md](secrets.md)).
3. Deploy via CI.

## Firewall (UFW)

Open: 22 (SSH), 80, 443, and 8080 (Traefik dashboard). Port 8080 should be restricted to a known IP:

```bash
ufw delete allow 8080
ufw allow from <YOUR_IP> to any port 8080
```

## TLS

Traefik gets and renews Let's Encrypt certificates automatically. Config: `/opt/traefik/traefik.yml` (ACME email). Certificates: `/opt/traefik/acme.json`. HTTP redirects to HTTPS.
