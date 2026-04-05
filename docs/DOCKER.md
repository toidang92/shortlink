# Docker Guide

## Build the Image

```bash
docker build -t shortlink .
```

### Build with a specific Ruby version

```bash
docker build --build-arg RUBY_VERSION=3.4.7 -t shortlink .
```

### Build for a different platform

```bash
docker build --platform linux/amd64 -t shortlink .
```

## Run with Docker Compose (Development)

Start all services (PostgreSQL, Redis, and the app):

```bash
docker compose up -d
```

Stop all services:

```bash
docker compose down
```

## Run the Image Manually

### Prerequisites

PostgreSQL and Redis must be reachable. Start them first:

```bash
docker compose up -d postgres redis
```

### Run the app container

```bash
docker run -d \
  --name shortlink \
  --network shortlink_default \
  -p 3000:3000 \
  -e RAILS_ENV=production \
  -e RAILS_MASTER_KEY=$(cat config/master.key) \
  -e DATABASE_URL=postgres://postgres:postgres@postgres:5432/shortlink_production \
  -e REDIS_URL=redis://redis:6379/0 \
  shortlink
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `RAILS_MASTER_KEY` | Yes (production) | Key to decrypt `config/credentials.yml.enc` |
| `DATABASE_URL` | Yes (production) | PostgreSQL connection URL |
| `REDIS_URL` | No | Redis connection URL (default: `redis://localhost:6379/0`) |
| `REDIS_POOL_SIZE` | No | Connection pool size (default: `10`) |
| `RAILS_ENV` | No | Environment (default: `production`) |

## Image Details

The Dockerfile uses a multi-stage build:

```
┌─────────────────────────────────┐
│  Stage 1: base                  │
│  ruby:3.4.7-slim + libpq5      │
│  + jemalloc (memory optimizer)  │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│  Stage 2: build                 │
│  + build-essential, libpq-dev   │
│  + bundle install               │
│  + copy app code                │
└────────────┬────────────────────┘
             │ copy gems + app
┌────────────▼────────────────────┐
│  Stage 3: final                 │
│  base + gems + app (no compiler)│
│  runs as non-root user (1000)   │
│  EXPOSE 3000                    │
└─────────────────────────────────┘
```

- **jemalloc** — reduces memory fragmentation in long-running Ruby processes
- **Multi-stage** — final image has no build tools (smaller, more secure)
- **Non-root** — runs as `rails` user (UID 1000)
- **Entrypoint** — auto-runs `db:prepare` on server start (creates/migrates DB)

## Health Check

```bash
curl http://localhost:3000/up
```

## Production Tips

- Always set `RAILS_MASTER_KEY` via environment variable, never bake it into the image
- Use `docker compose` with named volumes for PostgreSQL data persistence
- Consider adding `--restart unless-stopped` for auto-restart
- Monitor with `docker logs shortlink -f`
