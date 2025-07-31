# 🚀 Deployment Guide

Premiere Ecoute is deployed to production using Fly.io. The deployment configuration is managed through the `fly.toml` file in the project root, which contains all necessary settings including application name, region settings, environment variables, build configuration, and service ports.

> **Important**: Only the project owner has deployment permissions. You'll need the Fly.io CLI installed and authenticated, along with access to the project repository. If you need deployment access, contact the current project owner.

## Commands

Before deploying to production, ensure that all changes have been commited. Deploying to production must be done through Fly.io CLI:
```bash
git commit -m "..."
git push origin main
fly deploy
```

After a successful launch, deployment can be monitored through logs:

```bash
fly logs
fly logs -f # follow logs in real-time
```
