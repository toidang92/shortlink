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
  -e DATABASE_URL=postgres://postgres:postgres@postgres:5432/shortlink_production \
  -e REDIS_URL=redis://redis:6379/0 \
  shortlink
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | Yes (production) | PostgreSQL connection URL |
| `REDIS_URL` | No | Redis connection URL (default: `redis://localhost:6379/0`) |
| `REDIS_POOL_SIZE` | No | Connection pool size (default: `10`) |
| `SHORTLINK_SECRET` | Yes | Hex string for XOR obfuscation (`openssl rand -hex 16`) |
| `CORS_ORIGINS` | No | Allowed CORS origins, comma-separated (default: `*`) |
| `RAILS_ENV` | No | Environment (default: `production`) |

### docker-compose.yml Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DB_USERNAME` | No | PostgreSQL user (default: `postgres`) |
| `DB_PASSWORD` | Yes | PostgreSQL password |
| `REDIS_PASSWORD` | Yes | Redis password |

## Image Details

The Dockerfile uses a multi-stage build:

```
┌─────────────────────────────────┐
│  Stage 1: base                  │
│  ruby:3.4.7-slim + libpq5      │
│  + jemalloc + tini + YJIT      │
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

- Use `docker compose` with named volumes for PostgreSQL data persistence
- Consider adding `--restart unless-stopped` for auto-restart
- Monitor with `docker logs shortlink -f`
