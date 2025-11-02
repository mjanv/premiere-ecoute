# Deployment Guide - Digital Ocean

This guide covers deploying the Premiere Ecoute application to a Digital Ocean droplet using Docker, Docker Compose, and Traefik as a reverse proxy.

## Prerequisites

- Digital Ocean droplet with Ubuntu (droplet IP: `68.183.219.251`)
- SSH access configured to the droplet
- Domain or using IP address for access
- Required API credentials (Spotify, Twitch, Discord, etc.)

## Architecture

The production deployment consists of:

- **App Container**: Phoenix/Elixir application running on port 4000
- **PostgreSQL**: Database with persistent volume storage
- **Traefik**: Reverse proxy handling HTTP/HTTPS traffic and SSL certificates

```
Internet
    ↓
Traefik (ports 80, 443)
    ↓
App Container (port 4000)
    ↓
PostgreSQL (internal network)
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

### 2. Deploy Using Automated Script

The easiest way to deploy is using the provided deployment script:

```bash
chmod +x deploy.sh
./deploy.sh
```

This script will:
1. Build the Elixir release locally
2. Create deployment directory on droplet (`/opt/premiere-ecoute`)
3. Copy release to droplet
4. Copy production environment configuration as `.env`
5. Install PostgreSQL, Traefik, and dependencies (first time only)
6. Install systemd services
7. Start all services (migrations run automatically via `ExecStartPre`)

### 3. Manual Deployment (Alternative)

If you prefer manual deployment:

#### 3.1. Copy Files to Droplet

```bash
rsync -avz --exclude='_build' \
           --exclude='deps' \
           --exclude='.git' \
           --exclude='node_modules' \
           . root@68.183.219.251:/opt/premiere-ecoute/

scp .env.production root@68.183.219.251:/opt/premiere-ecoute/
```

#### 3.2. Setup Server (First Time Only)

```bash
ssh root@68.183.219.251
cd /opt/premiere-ecoute
chmod +x setup-server.sh
./setup-server.sh
```

#### 3.3. Start Services

```bash
ssh root@68.183.219.251
cd /opt/premiere-ecoute

# Reload systemd and start services
systemctl daemon-reload
systemctl start premiere-ecoute

# Migrations run automatically before the app starts
# Check status
systemctl status premiere-ecoute
```

## Post-Deployment

### Verify Deployment

After deployment, verify the services are running:

```bash
ssh root@68.183.219.251
cd /opt/premiere-ecoute
docker compose -f docker-compose.prod.yml ps
```

All services should show as "Up" or "healthy".

### Access Points

- **Application**: https://68.183.219.251
- **Traefik Dashboard**: http://68.183.219.251:8080

### View Logs

```bash
# All services
ssh root@68.183.219.251 'cd /opt/premiere-ecoute && docker compose -f docker-compose.prod.yml logs -f'

# Specific service
ssh root@68.183.219.251 'cd /opt/premiere-ecoute && docker compose -f docker-compose.prod.yml logs -f app'
```

## Management Commands

### Restart Services

```bash
ssh root@68.183.219.251 'cd /opt/premiere-ecoute && docker compose -f docker-compose.prod.yml restart'
```

### Stop Services

```bash
ssh root@68.183.219.251 'cd /opt/premiere-ecoute && docker compose -f docker-compose.prod.yml down'
```

### Update Application

To deploy updates:

```bash
./deploy.sh
```

Or manually:

```bash
# Copy updated files
rsync -avz --exclude='_build' --exclude='deps' --exclude='.git' . root@68.183.219.251:/opt/premiere-ecoute/

# Rebuild and restart
ssh root@68.183.219.251 'cd /opt/premiere-ecoute && docker compose -f docker-compose.prod.yml up -d --build'

# Run new migrations if any
ssh root@68.183.219.251 'cd /opt/premiere-ecoute && docker compose -f docker-compose.prod.yml exec app bin/premiere_ecoute eval "PremiereEcoute.Repo.Release.migrate()"'
```

### Database Backup

```bash
ssh root@68.183.219.251 'cd /opt/premiere-ecoute && docker compose -f docker-compose.prod.yml exec postgres pg_dump -U postgres premiere_ecoute_prod > backup.sql'
```

### Database Restore

```bash
scp backup.sql root@68.183.219.251:/opt/premiere-ecoute/
ssh root@68.183.219.251 'cd /opt/premiere-ecoute && docker compose -f docker-compose.prod.yml exec -T postgres psql -U postgres premiere_ecoute_prod < backup.sql'
```

## SSL Certificates

Traefik automatically obtains and renews Let's Encrypt SSL certificates. Certificates are stored in `/opt/premiere-ecoute/letsencrypt/acme.json` on the droplet.

**Important**:
- Ensure `ACME_EMAIL` is set in `.env.production`
- Certificates are obtained when first accessing the application via HTTPS
- HTTP requests are automatically redirected to HTTPS

## Using a Custom Domain

To use a custom domain instead of the IP address:

1. Point your domain's DNS A record to `68.183.219.251`
2. Update `.env.production`:
   ```bash
   PHX_HOST=yourdomain.com
   SPOTIFY_REDIRECT_URI=https://yourdomain.com/auth/spotify/callback
   TWITCH_REDIRECT_URI=https://yourdomain.com/auth/twitch/callback
   TWITCH_WEBHOOK_CALLBACK_URL=https://yourdomain.com/webhooks/twitch
   ```
3. Update API application settings on Spotify and Twitch developer consoles
4. Redeploy: `./deploy.sh`

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

## Troubleshooting

### Services Not Starting

Check logs:
```bash
ssh root@68.183.219.251 'cd /opt/premiere-ecoute && docker compose -f docker-compose.prod.yml logs'
```

### Database Connection Issues

Verify PostgreSQL is healthy:
```bash
ssh root@68.183.219.251 'cd /opt/premiere-ecoute && docker compose -f docker-compose.prod.yml exec postgres pg_isready -U postgres'
```

### SSL Certificate Issues

Check Traefik logs:
```bash
ssh root@68.183.219.251 'cd /opt/premiere-ecoute && docker compose -f docker-compose.prod.yml logs traefik'
```

Verify `ACME_EMAIL` is set correctly in `.env.production`.

### Application Errors

View application logs:
```bash
ssh root@68.183.219.251 'cd /opt/premiere-ecoute && docker compose -f docker-compose.prod.yml logs -f app'
```

Connect to running container:
```bash
ssh root@68.183.219.251 'cd /opt/premiere-ecoute && docker compose -f docker-compose.prod.yml exec app sh'
```

## Security Considerations

1. **Change default passwords**: Ensure all passwords in `.env.production` are strong and unique
2. **Restrict Traefik dashboard**: Limit access to port 8080 or disable it in production
3. **Regular updates**: Keep Docker images and system packages updated
4. **Backup strategy**: Implement regular database backups
5. **Monitor logs**: Regularly check logs for suspicious activity
6. **API secrets**: Never commit `.env.production` to version control

## Adding Prometheus and Grafana

When ready to add observability:

1. Update `docker-compose.prod.yml` to include Prometheus and Grafana services (from `docker-compose.yml`)
2. Configure Grafana with proper authentication (remove anonymous access)
3. Update firewall rules if external access is needed
4. Update `config/runtime.exs` to enable PromEx Grafana integration

## Next Steps

- [ ] Configure custom domain
- [ ] Set up automated backups
- [ ] Configure monitoring and alerting
- [ ] Set up log aggregation
- [ ] Implement CI/CD pipeline
- [ ] Add Prometheus/Grafana for observability
