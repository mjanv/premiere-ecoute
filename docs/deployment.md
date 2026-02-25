# Deployment Guide - Digital Ocean

This guide covers deploying the Premiere Ecoute application to a Digital Ocean droplet using a native Elixir release with systemd services and Traefik as a reverse proxy.

## Prerequisites

- Digital Ocean droplet with Ubuntu (droplet IP: `68.183.219.251`)
- SSH access configured to the droplet
- Domain or using IP address for access
- Required API credentials (Spotify, Twitch, Discord, etc.)

## Architecture

The production deployment consists of:

- **Phoenix/Elixir Application**: Native Elixir release running as systemd service on port 4000
- **PostgreSQL**: Native installation managed by systemd
- **Traefik**: Reverse proxy handling HTTP/HTTPS traffic and SSL certificates (Let's Encrypt)

```
Internet
    ↓
Traefik (ports 80, 443)
    ↓
Phoenix App (port 4000) - systemd service
    ↓
PostgreSQL (localhost) - systemd service
```

## Deployment Steps

### 1. Prepare Local Environment

First, create your production environment file from the template:

```bash
cp .env.production.example .env.production
```

Edit `.env.production` and configure all required values:

**Critical settings to change:**
- `ACME_EMAIL`: Your email for Let's Encrypt SSL certificates
- `SECRET_KEY_BASE`: Generate with `mix phx.gen.secret`
- `POSTGRES_PASSWORD`: Strong database password
- `POSTGRES_ENCRYPTION_KEY`: Generate with `mix guardian.gen.secret | base64`
- `AUTH_PASSWORD`: Strong password for feature flags admin
- API credentials (Spotify, Twitch, Discord, BuyMeACoffee, etc.)

**URLs to update** (replace IP with your domain when ready):
- `PHX_HOST=68.183.219.251`
- `SPOTIFY_REDIRECT_URI=https://68.183.219.251/auth/spotify/callback`
- `TWITCH_REDIRECT_URI=https://68.183.219.251/auth/twitch/callback`
- `TWITCH_WEBHOOK_CALLBACK_URL=https://68.183.219.251/webhooks/twitch`

### 2. Automated Deployment (GitHub Actions)

**Recommended**: The easiest way to deploy is using the automated GitHub Actions workflow. See the [GitHub Actions CI/CD Pipeline](#github-actions-cicd-pipeline) section below for setup instructions.

### 3. Manual Deployment (Using Deployment Script)

For manual deployments from your local machine:

```bash
cd apps/digital_ocean
chmod +x deploy.sh
./deploy.sh
```

This script will:
1. Build the Elixir release locally (`MIX_ENV=prod mix release`)
2. Copy release to droplet (`/opt/premiere-ecoute`)
3. Copy production environment configuration as `.env`
4. Copy systemd service files and Traefik configuration
5. Restart the `premiere-ecoute` systemd service
6. Migrations run automatically via `ExecStartPre` in the systemd service

**First-time setup**: If this is your first deployment to the droplet, run `apps/digital_ocean/setup.sh` first to install PostgreSQL, Traefik, create system users, and configure the firewall.

### 4. Alternative Manual Deployment

If you prefer step-by-step manual deployment:

#### 4.1. Build Release Locally

```bash
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release --overwrite
```

#### 4.2. Copy Release to Droplet

```bash
rsync -avz --delete --exclude='.env' \
  _build/prod/rel/premiere_ecoute/ \
  root@68.183.219.251:/opt/premiere-ecoute/

scp .env.production root@68.183.219.251:/opt/premiere-ecoute/.env
```

#### 4.3. Restart Service

```bash
ssh root@68.183.219.251 'systemctl restart premiere-ecoute'

# Check status
ssh root@68.183.219.251 'systemctl status premiere-ecoute --no-pager'
```

## Post-Deployment

### Access Points

- **Application**: https://premiere-ecoute.fr (or https://68.183.219.251)
- **Traefik Dashboard**: http://68.183.219.251:8080

### Verify Deployment

After deployment, verify the services are running:

```bash
ssh root@68.183.219.251 'systemctl status premiere-ecoute --no-pager'
ssh root@68.183.219.251 'systemctl status traefik --no-pager'
ssh root@68.183.219.251 'systemctl status postgresql --no-pager'
```

### View Logs

```bash
ssh root@68.183.219.251 'journalctl -u premiere-ecoute -f'
ssh root@68.183.219.251 'journalctl -u traefik -f'
ssh root@68.183.219.251 'journalctl -u postgresql -f'
ssh root@68.183.219.251 'journalctl -u premiere-ecoute -u traefik -u postgresql -f'
```

## Management Commands

### Restart Services

```bash
ssh root@68.183.219.251 'systemctl restart premiere-ecoute'
ssh root@68.183.219.251 'systemctl restart traefik'
ssh root@68.183.219.251 'systemctl restart premiere-ecoute traefik'
```

### Stop Services

```bash
ssh root@68.183.219.251 'systemctl stop premiere-ecoute'
ssh root@68.183.219.251 'systemctl stop traefik'
```

### Update Application

**Recommended**: Push to `main` branch to trigger automated GitHub Actions deployment.

Or manually using the deployment script:

```bash
cd apps/digital_ocean
./deploy.sh
```

Migrations run automatically via the systemd service's `ExecStartPre` directive.

### Database Backup

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

### Database Restore

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

## SSL Certificates

Traefik automatically obtains and renews Let's Encrypt SSL certificates. Certificates are stored in `/opt/traefik/acme.json` on the droplet.

**Important**:
- The email for Let's Encrypt is configured in `/opt/traefik/traefik.yml` (currently set to `maxime.janvier+premiereecoute@gmail.com`)
- Certificates are obtained when first accessing the application via HTTPS
- HTTP requests are automatically redirected to HTTPS

## Using a Custom Domain

The application is currently configured to use `premiere-ecoute.fr` domain. To use a different custom domain:

1. Point your domain's DNS A record to `68.183.219.251`
2. Update GitHub Secrets (for automated deployments):
   - `PHX_HOST`: `yourdomain.com`
   - `SPOTIFY_REDIRECT_URI`: `https://yourdomain.com/auth/spotify/callback`
   - `TWITCH_REDIRECT_URI`: `https://yourdomain.com/auth/twitch/callback`
   - `TWITCH_WEBHOOK_CALLBACK_URL`: `https://yourdomain.com/webhooks/twitch`
3. Update API application settings on Spotify and Twitch developer consoles
4. Deploy: Push to `main` branch or run `./deploy.sh`

For manual deployments, update `.env.production` with the same values before deploying.

## Firewall Configuration

The setup script configures UFW firewall with these rules:
- Port 22 (SSH)
- Port 80 (HTTP)
- Port 443 (HTTPS)
- Port 8080 (Traefik dashboard - consider restricting access)

To restrict Traefik dashboard access:

```bash
ssh root@68.183.219.251
ufw delete allow 8080
ufw allow from YOUR_IP to any port 8080
```

## GitHub Actions CI/CD Pipeline

The repository includes an automated deployment pipeline via GitHub Actions that deploys to Digital Ocean on every push to the `main` branch.

### Workflow Overview

The deployment workflow (`.github/workflows/main.yml`) consists of two jobs:

1. **build-release**: Builds the production Elixir release
   - Sets up Erlang/Elixir environment
   - Caches dependencies and build artifacts for faster builds
   - Compiles assets (`mix assets.deploy`)
   - Creates production release (`MIX_ENV=prod mix release`)
   - Uploads release artifact for deployment

2. **deploy-to-digital-ocean**: Deploys the release to the droplet
   - Downloads release artifact from build job
   - Sets up SSH connection to droplet
   - Reconstructs `.env.production` from GitHub Secrets
   - Syncs release to `/opt/premiere-ecoute/` via rsync
   - Restarts the `premiere-ecoute` systemd service
   - Verifies deployment success

### Required GitHub Secrets

To enable automated deployments, configure the following secrets in your GitHub repository settings (**Settings → Secrets and variables → Actions → New repository secret**):

#### SSH Access
- `DO_SSH_PRIVATE_KEY`: Private SSH key for passwordless login to `root@68.183.219.251`

#### Phoenix/Application
- `PHX_HOST`: `premiere-ecoute.fr` (or your domain/IP)
- `SECRET_KEY_BASE`: Generate with `mix phx.gen.secret`

#### Database
- `POSTGRES_DATABASE`: `premiere_ecoute_prod`
- `POSTGRES_USERNAME`: `postgres`
- `POSTGRES_PASSWORD`: Your database password
- `POSTGRES_ENCRYPTION_KEY`: Base64-encoded 32-byte key (generate with `mix guardian.gen.secret | base64`)

#### Spotify API
- `SPOTIFY_CLIENT_ID`: From Spotify Developer Dashboard
- `SPOTIFY_CLIENT_SECRET`: From Spotify Developer Dashboard
- `SPOTIFY_REDIRECT_URI`: `https://premiere-ecoute.fr/auth/spotify/callback`

#### Twitch API
- `TWITCH_CLIENT_ID`: From Twitch Developer Console
- `TWITCH_CLIENT_SECRET`: From Twitch Developer Console
- `TWITCH_REDIRECT_URI`: `https://premiere-ecoute.fr/auth/twitch/callback`
- `TWITCH_WEBHOOK_CALLBACK_URL`: `https://premiere-ecoute.fr/webhooks/twitch`
- `TWITCH_EXTENSION_SECRET`: Your webhook secret

#### Other APIs
- `DISCORD_BOT_TOKEN`: Discord bot token
- `BUYMEACOFFEE_API_KEY`: Buy Me a Coffee API key
- `RESEND_API_KEY`: Resend API key (for email via Swoosh)
- `OPENAI_API_KEY`: OpenAI API key
- `SENTRY_DSN`: Sentry DSN for error tracking

#### Feature Flags Authentication
- `AUTH_USERNAME`: Admin username for feature flags
- `AUTH_PASSWORD`: Admin password for feature flags

### Setting Up SSH Access

1. **Generate SSH key pair** (if you don't have one):
   ```bash
   ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/premiere_ecoute_deploy
   ```

2. **Add public key to droplet**:
   ```bash
   ssh-copy-id -i ~/.ssh/premiere_ecoute_deploy.pub root@68.183.219.251
   ```

3. **Add private key to GitHub Secrets**:
   ```bash
   cat ~/.ssh/premiere_ecoute_deploy
   # Copy the entire output (including BEGIN and END lines)
   # Add as DO_SSH_PRIVATE_KEY secret in GitHub
   ```

### Triggering Deployments

Deployments are triggered automatically:
- On every push to the `main` branch
- Can be manually triggered via **Actions → Deploy to Production → Run workflow**
