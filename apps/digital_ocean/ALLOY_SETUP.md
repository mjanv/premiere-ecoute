# Grafana Alloy Setup - Final Steps

Grafana Alloy has been successfully installed on your Digital Ocean droplet! However, it needs your Grafana Cloud credentials to start pushing metrics.

## Current Status

✅ Alloy v1.5.1 installed
✅ Configuration files in place
✅ Systemd service enabled
⏸️ Service NOT started (waiting for credentials)

## Add Your Grafana Cloud Credentials

### 1. Get Your Credentials

Visit your Grafana Cloud stack: https://grafana.com/orgs/<your-org>/stacks

You'll need:
- **Prometheus URL**: Your Prometheus push endpoint (e.g., `https://prometheus-prod-XX-prod-XX-XX.grafana.net/api/prom/push`)
- **Username**: Your Prometheus instance ID (e.g., `123456`)
- **API Key**: A Grafana Cloud API key with `MetricsPublisher` role

### 2. Configure Environment Variables

SSH into your droplet and edit the environment file:

```bash
ssh root@68.183.219.251
nano /etc/alloy/env
```

Replace the placeholder values:

```bash
# Grafana Cloud Prometheus configuration
GRAFANA_CLOUD_PROMETHEUS_URL=https://prometheus-prod-XX-prod-XX-XX.grafana.net/api/prom/push
GRAFANA_CLOUD_PROMETHEUS_USERNAME=123456
GRAFANA_CLOUD_API_KEY=your-actual-api-key-here
```

Save and exit (Ctrl+X, then Y, then Enter).

### 3. Start the Service

```bash
systemctl start alloy
```

### 4. Verify It's Working

Check service status:
```bash
systemctl status alloy
```

View logs (should show successful metric pushes):
```bash
journalctl -u alloy -f
```

Look for lines like:
```
level=info msg="Remote write sent" component=prometheus.remote_write.grafana_cloud
```

### 5. View Metrics in Grafana Cloud

1. Go to your Grafana Cloud instance
2. Navigate to **Explore**
3. Select your Prometheus data source
4. Try a query:
   ```promql
   {job="premiere-ecoute", instance="premiere-ecoute-do"}
   ```

## Useful Commands

```bash
# Service management
systemctl status alloy                    # Check status
systemctl start alloy                     # Start service
systemctl stop alloy                      # Stop service
systemctl restart alloy                   # Restart service
systemctl reload alloy                    # Reload config without restart

# Logs
journalctl -u alloy -f                    # Follow logs
journalctl -u alloy -n 100                # Last 100 lines
journalctl -u alloy --since "10 min ago"  # Last 10 minutes

# Configuration
nano /etc/alloy/config.alloy              # Edit config
alloy fmt /etc/alloy/config.alloy         # Validate config syntax
```

## Troubleshooting

### Service Won't Start

Check the logs for errors:
```bash
journalctl -u alloy -n 50
```

Common issues:
- Missing/invalid credentials in `/etc/alloy/env`
- Network connectivity issues
- Configuration syntax errors

### Not Seeing Metrics in Grafana Cloud

1. Verify Alloy is running: `systemctl status alloy`
2. Check logs for push errors: `journalctl -u alloy | grep -i error`
3. Test credentials manually:
   ```bash
   source /etc/alloy/env
   curl -u "$GRAFANA_CLOUD_PROMETHEUS_USERNAME:$GRAFANA_CLOUD_API_KEY" \
        -X POST "$GRAFANA_CLOUD_PROMETHEUS_URL" \
        -H "Content-Type: application/x-protobuf" \
        -d ""
   ```
4. Verify app is exposing metrics: `curl localhost:4000/metrics`

### High Memory Usage

Alloy is configured with a 200MB limit. Check current usage:
```bash
systemctl show alloy --property=MemoryCurrent
```

If needed, adjust limits in `/etc/systemd/system/alloy.service` and reload:
```bash
nano /etc/systemd/system/alloy.service
systemctl daemon-reload
systemctl restart alloy
```

## What Metrics Are Being Collected?

Alloy scrapes metrics from `http://localhost:4000/metrics` every 15 seconds, including:

- **Phoenix metrics**: Request rates, response times, errors
- **Erlang VM metrics**: Memory usage, process counts, garbage collection
- **PromEx metrics**: Custom application metrics
- **System metrics**: CPU, memory, network

All metrics are tagged with:
- `job="premiere-ecoute"`
- `instance="premiere-ecoute-do"`
- `environment="production"`

## Next Steps

After starting Alloy:

1. Check that metrics are flowing to Grafana Cloud
2. Create dashboards in Grafana Cloud (or import PromEx dashboards)
3. Set up alerts for critical metrics (high error rates, memory usage, etc.)
4. Consider adding more scrape targets if needed

## Files Reference

- **Configuration**: `/etc/alloy/config.alloy`
- **Environment**: `/etc/alloy/env`
- **Service**: `/etc/systemd/system/alloy.service`
- **Data**: `/var/lib/alloy/`
- **Binary**: `/usr/local/bin/alloy`
