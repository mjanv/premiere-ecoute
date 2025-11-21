# Digital Ocean Deployment

This directory contains scripts and configuration files for deploying Premiere Ecoute on Digital Ocean.

## Infrastructure Overview

The application runs on a Digital Ocean droplet with the following components:

- **Premiere Ecoute**: Phoenix application (Elixir/OTP)
- **PostgreSQL**: Database server
- **Traefik**: Reverse proxy and SSL termination
- **Grafana Alloy**: Metrics collection agent (sends to Grafana Cloud)

All services run natively via systemd (no Docker on production).

## Directory Structure

```
apps/digital_ocean/
├── README.md                    # This file
├── setup.sh                     # One-time server setup
├── install-alloy.sh             # Install Grafana Alloy
├── deploy.sh                    # Deploy application updates
├── backup.sh                    # Database backup
├── restore.sh                   # Database restoration
├── load-github-secrets.sh       # Load secrets to GitHub Actions
├── systemd/
│   ├── premiere-ecoute.service  # Application systemd service
│   ├── traefik.service          # Traefik systemd service
│   └── alloy.service            # Grafana Alloy systemd service
├── traefik/
│   ├── traefik.yml              # Traefik static configuration
│   └── dynamic.yml              # Traefik dynamic configuration
└── alloy/
    ├── config.alloy             # Alloy configuration
    └── env.example              # Environment variables template
```

## Initial Server Setup

### 1. Setup Base Infrastructure

Run the setup script on your Digital Ocean droplet:

```bash
sudo ./setup.sh
```

This installs:
- PostgreSQL
- Traefik reverse proxy
- Required system packages
- Application user accounts

### 2. Configure Traefik

Copy Traefik configuration files:

```bash
sudo mkdir -p /opt/traefik
sudo cp traefik/traefik.yml /opt/traefik/
sudo cp traefik/dynamic.yml /opt/traefik/
sudo chown -R traefik:traefik /opt/traefik
```

Install and start Traefik service:

```bash
sudo cp systemd/traefik.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable traefik
sudo systemctl start traefik
```

### 3. Install Grafana Alloy

Install Alloy for metrics collection:

```bash
sudo ./install-alloy.sh
```

Configure Alloy with your Grafana Cloud credentials:

```bash
# Copy configuration files
sudo mkdir -p /etc/alloy
sudo cp alloy/config.alloy /etc/alloy/
sudo cp alloy/env.example /etc/alloy/env

# Edit environment file with your Grafana Cloud credentials
sudo nano /etc/alloy/env
```

Get your Grafana Cloud credentials from: https://grafana.com/orgs/<your-org>/stacks

You'll need:
- `GRAFANA_CLOUD_PROMETHEUS_URL`: Your Prometheus endpoint URL
- `GRAFANA_CLOUD_PROMETHEUS_USERNAME`: Your instance ID
- `GRAFANA_CLOUD_API_KEY`: API key with metrics push permissions

Install and start Alloy service:

```bash
sudo cp systemd/alloy.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable alloy
sudo systemctl start alloy
```

Verify Alloy is running:

```bash
sudo systemctl status alloy
sudo journalctl -u alloy -f
```

### 4. Deploy Application

Deploy the Premiere Ecoute application:

```bash
./deploy.sh
```

This will:
- Build a release on the server
- Run database migrations
- Install the systemd service
- Start the application

## Service Management

### Application

```bash
# Status
sudo systemctl status premiere-ecoute

# Start/Stop/Restart
sudo systemctl start premiere-ecoute
sudo systemctl stop premiere-ecoute
sudo systemctl restart premiere-ecoute

# View logs
sudo journalctl -u premiere-ecoute -f
```

### Traefik

```bash
# Status
sudo systemctl status traefik

# Start/Stop/Restart
sudo systemctl start traefik
sudo systemctl stop traefik
sudo systemctl restart traefik

# View logs
sudo journalctl -u traefik -f
```

### Grafana Alloy

```bash
# Status
sudo systemctl status alloy

# Start/Stop/Restart
sudo systemctl start alloy
sudo systemctl stop alloy
sudo systemctl restart alloy

# View logs
sudo journalctl -u alloy -f

# Reload configuration (without restart)
sudo systemctl reload alloy
```

## Monitoring

### Application Metrics

The application exposes Prometheus metrics at `http://localhost:4000/metrics`.

Grafana Alloy scrapes these metrics every 15 seconds and pushes them to Grafana Cloud.

### PromEx Dashboards

The application uses PromEx to automatically upload pre-built Grafana dashboards to your Grafana Cloud instance on startup. This includes dashboards for:
- Application metrics
- BEAM VM metrics
- Phoenix web framework metrics
- Ecto database metrics
- Phoenix LiveView metrics

#### Enable Dashboard Upload

To enable automatic dashboard upload:

1. **Create a Grafana API Token**:
   - Go to https://yourorg.grafana.net/org/apikeys
   - Click "Add API key"
   - Name: "PromEx Dashboard Upload"
   - Role: **Editor** (required to create dashboards)
   - Click "Add"
   - Copy the generated token immediately (you won't be able to see it again)

2. **Add credentials to the server**:
   ```bash
   # Upload and run the script
   scp apps/digital_ocean/add-grafana-credentials.sh root@68.183.219.251:/tmp/
   ssh root@68.183.219.251 'bash /tmp/add-grafana-credentials.sh'
   ```

   Or manually add to `/opt/premiere-ecoute/.env`:
   ```bash
   GRAFANA_HOST=https://yourorg.grafana.net
   GRAFANA_API_TOKEN=your_api_token_here
   ```

3. **Restart the application**:
   ```bash
   ssh root@68.183.219.251 'systemctl restart premiere-ecoute'
   ```

4. **Verify dashboards were uploaded**:
   - Check logs: `ssh root@68.183.219.251 'journalctl -u premiere-ecoute | grep -i grafana'`
   - Go to your Grafana Cloud instance
   - Navigate to **Dashboards**
   - Look for a folder named **"Premiere Ecoute"**
   - You should see 5 dashboards uploaded by PromEx

### Viewing Metrics

Access your metrics in Grafana Cloud:
1. Go to your Grafana Cloud instance
2. Navigate to Explore
3. Select your Prometheus data source
4. Query metrics with labels: `{job="premiere-ecoute", instance="premiere-ecoute-do"}`

### Common Metric Queries

```promql
# Request rate
rate(phoenix_router_dispatch_duration_count[5m])

# Response time p99
histogram_quantile(0.99, rate(phoenix_router_dispatch_duration_bucket[5m]))

# Memory usage
erlang_vm_memory_bytes_total{kind="total"}

# Active connections
phoenix_endpoint_stop_duration_count
```

## Database Operations

### Backup

Create a database backup:

```bash
./backup.sh
```

Backups are stored in `/opt/backups/premiere-ecoute/`.

### Restore

Restore from a backup:

```bash
./restore.sh /path/to/backup.sql
```

## Troubleshooting

### Check Service Status

```bash
# All services
sudo systemctl status premiere-ecoute traefik alloy postgresql

# Individual service logs
sudo journalctl -u premiere-ecoute -n 100
sudo journalctl -u traefik -n 100
sudo journalctl -u alloy -n 100
```

### Alloy Not Sending Metrics

1. Check Alloy is running: `sudo systemctl status alloy`
2. Verify configuration: `sudo alloy fmt /etc/alloy/config.alloy`
3. Check credentials in `/etc/alloy/env`
4. View Alloy logs: `sudo journalctl -u alloy -f`
5. Test connectivity to Grafana Cloud:
   ```bash
   curl -u "USERNAME:API_KEY" -X POST "PROMETHEUS_URL" -d ""
   ```

### Application Not Accessible

1. Check if application is running: `sudo systemctl status premiere-ecoute`
2. Verify application is listening: `sudo netstat -tlnp | grep 4000`
3. Check Traefik is running: `sudo systemctl status traefik`
4. Check firewall rules: `sudo ufw status`

### High Memory Usage

Memory limits are configured in systemd services:
- Premiere Ecoute: 600MB max
- Alloy: 200MB max
- PostgreSQL: Uses remaining memory

Check current usage:
```bash
sudo systemctl show premiere-ecoute --property=MemoryCurrent
sudo systemctl show alloy --property=MemoryCurrent
```

## Security Notes

- All services run as non-root users
- Systemd security hardening is enabled (NoNewPrivileges, PrivateTmp, etc.)
- Grafana Cloud credentials are stored in `/etc/alloy/env` (readable only by alloy user)
- Traefik handles SSL/TLS termination
- Firewall (UFW) restricts access to necessary ports only

## Updating

### Update Application

```bash
./deploy.sh
```

### Update Alloy

To update Grafana Alloy to a new version:

1. Edit `install-alloy.sh` and update `ALLOY_VERSION`
2. Run: `sudo ./install-alloy.sh`
3. Restart service: `sudo systemctl restart alloy`

## Resource Usage

Typical memory usage on a 1GB droplet:
- Premiere Ecoute: ~400-500MB
- PostgreSQL: ~200-250MB
- Traefik: ~20-30MB
- Alloy: ~50-100MB
- System: ~100-150MB

CPU usage is generally low (<10%) during normal operation.
