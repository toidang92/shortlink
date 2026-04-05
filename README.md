# Shortlink

[![Test: Unit tests](https://github.com/toidang92/shortlink/actions/workflows/unit-tests.yml/badge.svg)](https://github.com/toidang92/shortlink/actions/workflows/unit-tests.yml)
[![Security: Code Scanning](https://github.com/toidang92/shortlink/actions/workflows/security-code-scanning.yml/badge.svg)](https://github.com/toidang92/shortlink/actions/workflows/security-code-scanning.yml)

A URL shortening service built with Rails 8.1 API, PostgreSQL, and Redis Bloom Filter.

```
Client ──► Rack::Attack ──► Rails API ──► ShortenerService
              (rate limit)     (Puma)         │         │
                                         BloomService  Url Model
                                              │         │
                                           Redis    PostgreSQL
```

## Features

- **Encode** long URLs into short 6-character codes
- **Decode** short URLs back to original URLs
- **Redirect** via short code with 301 status
- **Bloom Filter** to minimize DB lookups on code generation
- **Rate Limiting** per IP (60 req/min global, 10 req/min for encode)
- **Connection Pooling** with hiredis C driver for Redis performance

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | Rails 8.1 (API mode) |
| Database | PostgreSQL 18 |
| Cache/Bloom | Redis Stack (RedisBloom) |
| Web Server | Puma |
| Rate Limiting | Rack::Attack |
| Testing | RSpec 7 |
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
# → {"short_url": "http://localhost:3000/a1B2c3"}

# Decode
curl -X POST http://localhost:3000/decode \
  -H "Content-Type: application/json" \
  -d '{"short_url": "http://localhost:3000/a1B2c3"}'
# → {"url": "https://example.com"}

# Redirect
curl -L http://localhost:3000/a1B2c3
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

## Documentation

- [Architecture](docs/ARCHITECTURE.md) - System design, request flows, component diagrams
- [Security](docs/SECURITY.md) - Threat model, OWASP coverage, security checklist
- [Setup](docs/SETUP.md) - Detailed setup guide, env vars, project structure
- [Testing](docs/TESTING.md) - How to run unit and integration tests
- [Docker](docs/DOCKER.md) - Build and run with Docker
