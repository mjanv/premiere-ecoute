# **Database**

Premiere Ecoute uses PostgreSQL deployed on Fly.io. The database configuration is managed through `fly.toml` and follows [Fly.io's PostgreSQL](https://fly.io/docs/postgres/) guidelines.

## **Connection**

Connect to the production database:

```bash
fly postgres connect
```

This opens a psql session directly to your Fly.io PostgreSQL instance.

## **Backup & Restore**

### **Create Backup**
```bash
# Start proxy in one terminal
fly proxy 15432:5432

# Create backup in another terminal
pg_dump "postgres://postgres:<password>@localhost:15432/postgres" > data/backup_$(date +%Y%m%d_%H%M%S).sql
```

### **Restore Backup**
```bash
# With proxy still running
psql "postgres://postgres:<password>@localhost:15432/postgres" < data/backup_<timestamp>.sql
```

Replace `<password>` with your actual database password and `<timestamp>` with the backup file timestamp.
