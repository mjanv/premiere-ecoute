# Database

To backup and restore the database:

```bash
# In a terminal
fly proxy 15432:5432
# In another terminal
pg_dump "postgres://postgres:<password>@localhost:15432/postgres" > data/backup_$(date +%Y%m%d_%H%M%S).sql
psql "postgres://postgres:<password>@localhost:15432/postgres" < data/backup_<timestamp>.sql
```