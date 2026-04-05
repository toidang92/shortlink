# Deployment

## Live URLs

| Service | URL | Description |
|---------|-----|-------------|
| Frontend | `https://shortlink.toidang.xyz` | Single-page web UI |
| API | `https://shortlink-api.toidang.xyz` | Rails API backend |

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Language** | Ruby 3.4.7 | Application language |
| **Framework** | Rails 8.1.3 (API mode) | Web framework |
| **Web Server** | Puma | Multi-threaded HTTP server |
| **Database** | PostgreSQL 18 (partman) | Primary data store |
| **Cache** | Redis 8.6.2 | Rate limiting (Rack::Attack) |
| **Frontend** | HTML + CSS + Vanilla JS | Single-page app |
| **Reverse Proxy** | Nginx (Alpine) | Frontend serving + API proxy |
| **Container** | Docker (multi-stage) | Application packaging |
| **CI/CD** | GitHub Actions | Automated testing + deployment |
| **Build** | Docker Buildx (Kubernetes driver) | Container image building |
| **Runner** | ARC (Actions Runner Controller) | Self-hosted CI runners on K8s |
| **Registry** | Private Docker Registry | Container image storage |
| **Process Manager** | tini | PID 1 signal handling |
| **Memory** | jemalloc | Reduced memory fragmentation |
| **JIT** | YJIT | Ruby JIT compiler for performance |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                         │
│                                                                   │
│  push/PR to main ──► code-check.yml (lint + security + test)    │
│  push tag v* ──────► build-image-self-host.yml (build + deploy) │
│  weekly schedule ──► security-code-scanning.yml (scan)          │
└──────────────────────────────┬────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Self-hosted Server                              │
│                                                                    │
│  ┌──────────────┐   ┌──────────────┐   ┌───────────────────┐    │
│  │   Frontend    │   │     API      │   │   PostgreSQL 18   │    │
│  │ nginx:alpine  │   │ ruby:3.4.7   │   │   (partman)       │    │
│  │ :80           │   │ :3000        │   │   :5432            │    │
│  └──────┬───────┘   └──────┬───────┘   └───────────────────┘    │
│         │                   │                                     │
│         │  /encode ────────►│           ┌───────────────────┐    │
│         │  /decode ────────►│           │   Redis 8.6.2     │    │
│         │                   │──────────►│   (rate limiting)  │    │
│         │                   │           │   :6379            │    │
│  static files (index.html)  │           └───────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

## CI/CD Pipelines

### 1. Code Check (`code-check.yml`)

**Triggers:** push/PR to `main`

```
┌─────────────────────────────────────────────────┐
│              code-check.yml                      │
│                                                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │
│  │  Lint     │  │ Security │  │    Test       │  │
│  │ rubocop  │  │ brakeman │  │ rspec (66)    │  │
│  │          │  │          │  │               │  │
│  │          │  │          │  │ + postgres:18 │  │
│  │          │  │          │  │ + redis:8.6.2 │  │
│  └──────────┘  └──────────┘  └──────────────┘  │
│   (parallel)    (parallel)    (parallel)         │
└─────────────────────────────────────────────────┘
```

3 jobs run in parallel:
- **Lint** — RuboCop style checks
- **Security** — Brakeman vulnerability scan
- **Test** — RSpec with PostgreSQL + Redis services

### 2. Security Scanning (`security-code-scanning.yml`)

**Triggers:** push/PR to `main` + weekly schedule (Sunday 00:00 UTC)

```
┌─────────────────────────────────────────────────┐
│         security-code-scanning.yml               │
│                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌────────┐│
│  │  Brakeman     │  │ Bundle Audit │  │ CodeQL ││
│  │  → SARIF      │  │ → gem CVEs   │  │ → Ruby ││
│  │  → GitHub     │  │              │  │  SAST  ││
│  │    Security   │  │              │  │        ││
│  └──────────────┘  └──────────────┘  └────────┘│
│   (parallel)        (parallel)        (parallel) │
└─────────────────────────────────────────────────┘
```

3 jobs run in parallel:
- **Brakeman** — Rails security scanner, uploads SARIF to GitHub Security tab
- **Bundle Audit** — Checks Gemfile.lock for known CVEs
- **CodeQL** — GitHub's static analysis for Ruby

### 3. Build & Deploy (`build-image-self-host.yml`)

**Triggers:** push git tag `v*` OR manual `workflow_dispatch`

```
┌──────────────────────────────────────────────────────────────┐
│              build-image-self-host.yml                         │
│                                                                │
│  Tag Computation:                                              │
│    git tag push  → tag name (e.g. v1.0.0)                     │
│    manual + custom_tag → custom_tag                            │
│    manual (no tag) → v-YYYYMMDD-<sha6> (e.g. v-20260406-abc123)│
│                                                                │
│  ┌─────────────────┐    ┌─────────────────────┐               │
│  │  Build API       │    │  Build Frontend      │               │
│  │                  │    │                      │               │
│  │ Dockerfile       │    │ frontend/Dockerfile  │               │
│  │ → Buildx (K8s)  │    │ → Buildx (K8s)       │               │
│  │ → Push to       │    │ → Push to            │               │
│  │   registry      │    │   registry           │               │
│  └────────┬────────┘    └──────────┬───────────┘               │
│           │                        │                           │
│           └────────┬───────────────┘                           │
│                    ▼                                           │
│           ┌────────────────┐                                   │
│           │    Deploy       │                                   │
│           │                │                                   │
│           │ SSH to host    │                                   │
│           │ → sed IMAGE_TAG│                                   │
│           │ → docker pull  │                                   │
│           │ → docker up -d │                                   │
│           └────────────────┘                                   │
└──────────────────────────────────────────────────────────────┘
```

**Build phase** (parallel):
1. **Build API** — Multi-stage Docker build (Ruby 3.4.7 slim + jemalloc + YJIT)
2. **Build Frontend** — nginx:alpine with index.html + nginx.conf

Both use Docker Buildx with Kubernetes driver on self-hosted ARC runners. Images are pushed to a private registry with registry-level caching.

**Deploy phase** (after both builds succeed):
1. SSH to deploy host
2. Update `IMAGE_TAG` in `.env` via `sed`
3. Pull new images: `docker compose pull api frontend`
4. Recreate containers: `docker compose up -d --force-recreate api frontend`

**Concurrency:** Only one deploy can run at a time (`concurrency: deploy-shortlink`). New deploys cancel in-progress ones.

## Docker Images

### API Image (multi-stage build)

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
│  + bundle install (production)  │
│  + copy app code                │
└────────────┬────────────────────┘
             │ copy gems + app
┌────────────▼────────────────────┐
│  Stage 3: final                 │
│  base + gems + app (no compiler)│
│  runs as non-root user (1000)   │
│  EXPOSE 3000                    │
│  ENTRYPOINT: tini → rails server│
│  db:prepare on startup          │
└─────────────────────────────────┘
```

**Optimizations:**
- **jemalloc** — reduces memory fragmentation in long-running Ruby processes
- **YJIT** — Ruby JIT compiler enabled via `RUBY_YJIT_ENABLE=1`
- **Multi-stage** — final image has no build tools (smaller, more secure)
- **Non-root** — runs as `rails` user (UID 1000)
- **tini** — proper PID 1 signal handling (graceful shutdown)
- **db:prepare** — auto-runs migrations on container start

### Frontend Image

```
┌─────────────────────────────────┐
│  nginx:alpine                   │
│  + custom nginx.conf            │
│  + index.html                   │
│  EXPOSE 80                      │
│                                  │
│  Routes:                         │
│    /          → index.html       │
│    /encode    → proxy to api:3000│
│    /decode    → proxy to api:3000│
└─────────────────────────────────┘
```

## Environment Variables (Production)

### Required

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string |
| `SHORTLINK_SECRET` | Hex string for XOR obfuscation (immutable, `openssl rand -hex 16`) |
| `SECRET_KEY_BASE` | Rails secret for session/cookies |
| `DB_PASSWORD` | PostgreSQL password (for docker-compose) |
| `REDIS_PASSWORD` | Redis password (for docker-compose) |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_URL` | `redis://localhost:6379/0` | Redis connection URL |
| `CORS_ORIGINS` | `*` | Allowed origins (comma-separated) |
| `RAILS_MAX_THREADS` | `5` | Puma thread count |
| `RAILS_LOG_LEVEL` | `info` | Log verbosity |
| `PORT` | `3000` | API server port |

### GitHub Actions Secrets/Variables

| Name | Type | Description |
|------|------|-------------|
| `DEPLOY_SSH_KEY` | Secret | SSH private key for deploy host |
| `REGISTRY_URL` | Variable | Private Docker registry URL |
| `DEPLOY_HOST` | Variable | Deploy server hostname/IP |
| `DEPLOY_USER` | Variable | SSH user on deploy host |
| `DEPLOY_PATH` | Variable | Path to docker-compose on deploy host |

## Manual Deployment

### Deploy a specific branch/tag

```bash
# Via GitHub Actions UI:
# Go to Actions → "CI/CD: Build & Deploy" → Run workflow
# - branch_or_tag: main (or any branch/tag)
# - custom_tag: staging (optional, auto-generates if empty)
```

### Deploy via git tag

```bash
git tag v1.0.0
git push origin v1.0.0
# → Automatically triggers build + deploy
```

### Deploy manually via SSH

```bash
ssh user@host
cd /path/to/shortlink

# Update image tag
sed -i 's/^IMAGE_TAG=.*/IMAGE_TAG=v1.0.0/' .env

# Pull and restart
docker compose pull api frontend
docker compose up -d --force-recreate api frontend
```

## Rollback

```bash
ssh user@host
cd /path/to/shortlink

# Revert to previous tag
sed -i 's/^IMAGE_TAG=.*/IMAGE_TAG=<previous-tag>/' .env

# Pull and restart
docker compose pull api frontend
docker compose up -d --force-recreate api frontend
```

## Health Check

```bash
# API health
curl https://shortlink-api.toidang.xyz/up
# → 200 OK

# Frontend
curl https://shortlink.toidang.xyz/
# → 200 OK (HTML)
```

## Key Design Decisions

| Decision | Why |
|----------|-----|
| Self-hosted runner (ARC) | Cost savings, private registry access, Kubernetes build driver |
| Docker Buildx with K8s driver | Builds run as K8s pods, resource-limited, parallelized |
| Registry-level cache | Faster rebuilds, shared across builds |
| `sed` + `docker compose` deploy | Simple, no K8s overhead for single-server deployment |
| Concurrency lock | Prevents race conditions during parallel deploys |
| tini as PID 1 | Proper signal forwarding, zombie process reaping |
| jemalloc + YJIT | Memory efficiency + performance for Ruby |
| `db:prepare` on startup | Auto-migrates on deploy, no separate migration step |
| `SHORTLINK_SECRET` immutable | Changing it breaks all existing short codes |
