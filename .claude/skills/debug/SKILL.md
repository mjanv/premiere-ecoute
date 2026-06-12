---
name: debug
description: Production debugging session for Premiere Ecoute. Pull live signals from Sentry, Grafana, and prod logs to diagnose what's wrong. Use when the user reports an incident, sees errors, or wants a health check.
---

# Production Debugging

> SSH access and restart commands: see `docs/deployment.md`.

## Available tools

| Tool | What it gives you |
|---|---|
| Sentry MCP | Unresolved issues, event details, stacktraces |
| Grafana MCP | PromQL queries, Loki log queries, dashboard panels, metric history |
| SSH to prod | Live logs, process status |

## Workflow

### 0. Create investigation document

Before doing anything else, create a file `YYYY-MM-DD-<short-slug>.md` describing the reported symptom. Fill it in as the investigation progresses — do not wait until the end.

```markdown
# Investigation: <short description>

**Date**: YYYY-MM-DD
**Reported symptom**: <what the user observed>

## Signals

### Sentry
<!-- unresolved issues found -->

### Grafana
<!-- metric anomalies -->

### Logs
<!-- relevant log lines -->

## Timeline
<!-- correlate events with timestamps -->

## Root cause
<!-- conclusion once identified -->

## Resolution
<!-- what was done, pending user confirmation for restarts -->
```

### 1. Triage — run all three in parallel

Pull signals simultaneously, don't wait for one before starting the next.

**Sentry** — unresolved issues:
```
mcp__sentry__search_issues(organizationSlug="maxime-janvier", projectSlug="premiere-ecoute", query="is:unresolved")
```

**Grafana** — 5xx error rate over last 30 min:
```
mcp__grafana__query_prometheus(
  datasourceUid="grafanacloud-mjanv-prom",
  expr="sum(rate(premiere_ecoute_prom_ex_phoenix_http_requests_total{status=~\"5..\"}[5m])) / sum(rate(premiere_ecoute_prom_ex_phoenix_http_requests_total[5m])) * 100",
  start="now-30m", end="now", step="1m"
)
```

**Loki** — last 50 error log lines:
```
mcp__grafana__query_loki_logs(
  datasourceUid="grafanacloud-logs",
  logql="{app=\"premiere-ecoute\", detected_level=\"error\"}",
  limit=50
)
```

**Prod logs** (fallback if Loki has no data yet) — last 50 error lines:
```bash
journalctl -u premiere-ecoute --no-pager -n 50 -p err
```

### 2. Focus

Based on triage, narrow down:

- **Sentry issue** → `mcp__sentry__get_sentry_resource` for full stacktrace and breadcrumbs
- **Metric spike** → query Grafana for the specific metric with finer resolution, break down by label (path, status, source)
- **Log pattern** → query Loki with `|= "keyword"` to filter by message, or use `detected_level="error"` for errors; fall back to SSH grep if needed

### 3. Correlate with deploys

On the server:

```bash
journalctl -u premiere-ecoute --no-pager --since "1 hour ago" | grep -E "started|stopped|Starting|Stopping"
```

A restart shortly before the error spike = likely a deploy or crash loop.

### 4. Common failure modes

| Symptom | First thing to check |
|---|---|
| 502/503 spike | `systemctl status premiere-ecoute` — is the app up? |
| Spotify errors | Sentry for `SpotifyApi` exceptions; check token expiry |
| DB timeouts | Grafana Ecto p95 latency by table; check connection pool |
| Memory growth | Grafana BEAM memory panel; look for binary or process growth |
| Job backlog | Grafana Jobs enqueued stat; Oban queue depth via PromQL |

### 5. Resolve

- Resolve false-positive Sentry issues: `mcp__sentry__update_issue(status="resolved")`
- If a restart or a modification is needed: present findings to the user and **ask for explicit confirmation before**

## Key Loki queries

```logql
# All errors
{app="premiere-ecoute", detected_level="error"}

# Errors in a time window
{app="premiere-ecoute", detected_level="error"} | since="30m"

# Filter by keyword
{app="premiere-ecoute"} |= "SpotifyApi"
{app="premiere-ecoute"} |= "Postgrex.Error"
{app="premiere-ecoute"} |= "GenServer"

# Error rate over time (metric query)
sum(count_over_time({app="premiere-ecoute", detected_level="error"}[5m]))
```

## Key metrics

```promql
# Error rate
sum(rate(premiere_ecoute_prom_ex_phoenix_http_requests_total{status=~"5.."}[5m])) / sum(rate(premiere_ecoute_prom_ex_phoenix_http_requests_total[5m])) * 100

# p95 latency by path
histogram_quantile(0.95, sum by (le, path) (rate(premiere_ecoute_prom_ex_phoenix_http_request_duration_milliseconds_bucket[5m])))

# BEAM memory total
avg(premiere_ecoute_prom_ex_beam_memory_processes_total_bytes)

# Oban queue depth
sum(premiere_ecoute_prom_ex_oban_queue_length_count{state="available"})

# Ecto p95 by table
histogram_quantile(0.95, sum by (le, source) (rate(premiere_ecoute_prom_ex_ecto_repo_query_total_time_milliseconds_bucket[5m])))
```
