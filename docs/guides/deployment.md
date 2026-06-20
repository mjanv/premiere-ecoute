# 🚀 Deployment Guide

Premiere Ecoute is deployed to a DigitalOcean VPS (`68.183.219.251`) as a systemd service. Deployments are triggered automatically on every push to `main` via GitHub Actions (`.github/workflows/main.yml`): the workflow builds an Elixir release, rsync's it to the server, and restarts the service.

> **Important**: Only the project owner has deployment access. The SSH key is stored in the `DO_SSH_PRIVATE_KEY` GitHub secret.

## Deploying

Push to `main` — the GitHub Actions workflow handles everything:

```bash
git push origin main
```

To deploy manually without a push, trigger the workflow from the GitHub Actions UI (workflow_dispatch).

## Monitoring logs on the server

```bash
ssh root@68.183.219.251
journalctl -u premiere-ecoute -f          # follow live
journalctl -u premiere-ecoute -n 100      # last 100 lines
journalctl -u premiere-ecoute --since "1 hour ago"
```

## Observability

### Metrics (Prometheus → Grafana Cloud)

[Grafana Alloy](https://grafana.com/docs/alloy/latest/) runs on the server and scrapes the Phoenix `/metrics` endpoint every 15s, forwarding to Grafana Cloud Prometheus. Dashboards are available at `mjanv.grafana.net`.

PromEx also uploads dashboards automatically on app startup (`upload_dashboards_on_start: true`).

### Logs (journald → Grafana Cloud Loki)

Alloy tails the `premiere-ecoute.service` systemd unit and ships logs to Grafana Cloud Loki. Query them in Grafana Cloud → Explore → `grafanacloud-mjanv-logs` datasource:

```logql
{app="premiere-ecoute"}                          # all logs
{app="premiere-ecoute", detected_level="error"}  # errors only
{app="premiere-ecoute"} |= "request_id"          # HTTP requests
```

### Alloy configuration

Config lives at `/etc/alloy/config.alloy` on the server. Credentials are in `/etc/alloy/env`. The service uses the `stack-724012-alloy-premiere-ecoute` access policy token from Grafana Cloud (needs `metrics:write` and `logs:write` scopes).

```bash
systemctl status alloy
journalctl -u alloy -f
```
