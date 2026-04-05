# Shortlink

[![CI](https://github.com/toidang92/shortlink/actions/workflows/ci.yml/badge.svg)](https://github.com/toidang92/shortlink/actions/workflows/ci.yml)
[![Security](https://github.com/toidang92/shortlink/actions/workflows/security.yml/badge.svg)](https://github.com/toidang92/shortlink/actions/workflows/security.yml)

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

## Quick Start

```bash
make setup    # docker up + bundle install + db create/migrate
make server   # start Rails on http://localhost:3000
```

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
