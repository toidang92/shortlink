# Shortlink

[![Test: Code check](https://github.com/toidang92/shortlink/actions/workflows/code-check.yml/badge.svg)](https://github.com/toidang92/shortlink/actions/workflows/code-check.yml)
[![Security: Code Scanning](https://github.com/toidang92/shortlink/actions/workflows/security-code-scanning.yml/badge.svg)](https://github.com/toidang92/shortlink/actions/workflows/security-code-scanning.yml)
[![Build: Docker Image](https://github.com/toidang92/shortlink/actions/workflows/build-image-self-host.yml/badge.svg)](https://github.com/toidang92/shortlink/actions/workflows/build-image-self-host.yml)

A URL shortening service built with Rails 8.1 API, PostgreSQL, and Redis.

```
Client ──► Rack::Attack ──► Rails API ──► ShortenerService
              (rate limit)     (Puma)         │         │
                                        Base62Service  ShortLink Model
                                        (ID obfuscate)      │
                                                        PostgreSQL
```

## Features

- **Encode** long URLs into short 11-character codes via Base62(ID XOR secret)
- **Decode** short URLs back to original URLs (reverse XOR + PK lookup)
- **Redirect** via short code with 301 status
- **Zero collisions** — deterministic code from DB ID via Base62(ID XOR secret)
- **Rate Limiting** per IP (60 req/min global, 10 req/min for encode)
- **Connection Pooling** with hiredis C driver for Redis performance

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | Rails 8.1 (API mode) |
| Database | PostgreSQL 18 |
| Cache | Redis (rate limiting) |
| Web Server | Puma |
| Rate Limiting | Rack::Attack |
| Testing | Rspec 8 |
| Linting | RuboCop |
| Security | Brakeman |

## Prerequisites

- **Ruby 3.4.7** (via [asdf](https://asdf-vm.com))
- **Docker & Docker Compose**
- **Make**

### Install asdf and Ruby

```bash
# Install asdf (macOS)
brew install asdf

# Add Ruby plugin
asdf plugin add ruby

# Install Ruby (reads .tool-versions)
asdf install ruby

# Verify
ruby --version   # → 3.4.7
```

### Install Make

```bash
# macOS (included with Xcode CLI tools)
xcode-select --install

# Ubuntu/Debian
sudo apt-get install make
```

## Quick Start

```bash
cp .env.example .env  # configure environment variables
make setup            # docker up + bundle install + db create/migrate
make server           # start Rails on http://localhost:3000
```

## Environment Variables

Copy `.env.example` to `.env` and adjust as needed:

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_USERNAME` | `postgres` | PostgreSQL username |
| `DB_PASSWORD` | `postgres` | PostgreSQL password |
| `DB_NAME` | `shortlink_development` | Database name |
| `DB_NAME_TEST` | `shortlink_test` | Test database name |
| `SHORTLINK_SECRET` | `0x5A3CF91D2E7B` | XOR secret for ID obfuscation (must never change) |
| `REDIS_URL` | `redis://localhost:6379/0` | Redis connection URL |
| `REDIS_POOL_SIZE` | `10` | Redis connection pool size |
| `REDIS_POOL_TIMEOUT` | `3` | Redis pool timeout (seconds) |
| `CORS_ORIGINS` | `*` | Allowed origins (comma-separated, see [CORS](#cors)) |
| `RAILS_MAX_THREADS` | `5` | Puma threads / DB pool size |
| `RAILS_LOG_LEVEL` | `info` | Log level (production) |
| `PORT` | `3000` | Server port |

## API

```bash
# Encode
curl -X POST http://localhost:3000/encode \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com"}'
# → {"short_url": "http://localhost:3000/aUBVMQWEHq8"}

# Decode
curl -X POST http://localhost:3000/decode \
  -H "Content-Type: application/json" \
  -d '{"short_url": "http://localhost:3000/aUBVMQWEHq8"}'
# → {"url": "https://example.com"}

# Redirect
curl -L http://localhost:3000/aUBVMQWEHq8
# → 301 redirect to https://example.com
```

## CORS

Cross-Origin Resource Sharing is configured via the `CORS_ORIGINS` environment variable.

```bash
# Allow all origins (default)
CORS_ORIGINS=*

# Allow a single origin
CORS_ORIGINS=https://example.com

# Allow multiple origins (comma-separated)
CORS_ORIGINS=https://example.com,https://app.example.com
```

Only `GET` and `POST` methods are allowed. See [config/initializers/cors.rb](config/initializers/cors.rb).

## Commands

```bash
make test       # run all specs
make lint       # rubocop check
make lint-fix   # rubocop auto-fix
make security   # brakeman scan
make check      # lint + security + test
```

## Security: Potential Attack Vectors

| Attack | Risk | Mitigation |
|--------|------|------------|
| **Brute-force code enumeration** | Attacker guesses valid short codes by exploiting sequential Base62-encoded IDs — nearby IDs map to nearby codes, making enumeration feasible | 62^11 ≈ 52 quadrillion combinations; XOR obfuscation scatters sequential IDs; rate limiting (60 req/min per IP). For stronger privacy, consider random non-sequential codes |
| **Spam / malicious URLs** | Phishing or malware links created | URL scheme whitelist (http/https only); encode rate limit (10/min per IP) |
| **Denial of Service (DoS)** | Flood requests to overload system | Rack::Attack rate limiting (Redis-backed); stateless servers scale horizontally |
| **Database overload** | Mass lookups or URL creation | Decode uses PK lookup O(1); connection pooling; indexed queries |
| **Collision attacks** | Overwrite existing URLs via same code | Mathematically impossible — XOR + Base62 are bijective; DB unique constraint |
| **SSRF** | Exploit internal network via URL fetching | System does NOT fetch URLs server-side — only stores and redirects |
| **Injection (SQL/XSS)** | Inject malicious code via input | ActiveRecord parameterized queries; `URI.parse` validation; JSON-only API |

Additional security measures:
- Brakeman static analysis (0 warnings)
- RuboCop code quality checks
- Sensitive parameter filtering in logs
- Non-root Docker user

See [Security Documentation](docs/SECURITY.md) for full threat model, OWASP Top 10 coverage, and security checklist.

## Scalability & Collision Handling

### Why collisions are impossible

Short codes are generated deterministically from the database auto-increment ID:

```
encode(id) = Base62( (id XOR SECRET) & MASK_64 ).rjust(11, '0')
```

Each step is a **bijection** (one-to-one mapping):
1. **XOR with SECRET** — invertible: `x XOR k XOR k = x`
2. **64-bit mask** — identity for DB IDs (always < 2^64)
3. **Base62 encoding** — unique number ↔ unique string
4. **Left-padding** — preserves uniqueness

**Therefore: different IDs always produce different codes. Zero collisions by mathematical proof.**

### Capacity

- 11-character Base62 codes support **62^11 ≈ 52 quadrillion** unique links
- PostgreSQL BIGSERIAL supports up to 9.2 quintillion IDs
- No retry loops or collision checks needed

### Scaling strategy

| Scale | Approach |
|-------|----------|
| **Current** | Single PostgreSQL + Redis, stateless Puma servers behind load balancer |
| **Read-heavy** | Add Redis cache for hot URLs; PostgreSQL read replicas |

The application servers are **stateless** — no session or local state. Horizontal scaling requires only a load balancer in front of multiple app instances sharing PostgreSQL + Redis.

See [Architecture Documentation](docs/ARCHITECTURE.md) and [Base62 Algorithm](docs/BASE62_ALGORITHM.md) for detailed analysis.

## Live Demo

| Service | URL |
|---------|-----|
| Frontend | [shortlink.toidang.xyz](https://shortlink.toidang.xyz) |
| API | [shortlink-api.toidang.xyz](https://shortlink-api.toidang.xyz) |

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — System design, request flows, CI/CD pipelines
- [Base62 Algorithm](docs/BASE62_ALGORITHM.md) — Encoding algorithm, collision proof, worked examples
- [Security](docs/SECURITY.md) — Threat model, OWASP coverage, security checklist
- [Setup](docs/SETUP.md) — Detailed setup guide, env vars, project structure
- [Testing](docs/TESTING.md) — Test guide, 66 examples across models/services/requests/form objects
- [Docker](docs/DOCKER.md) — Build and run with Docker
- [Deployment](docs/DEPLOYMENT.md) — CI/CD pipelines, build process, deploy to production
