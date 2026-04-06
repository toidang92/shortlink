# Architecture

## System Overview

Shortlink is a URL shortening service built with Rails 8.1 API, PostgreSQL, and Redis.

```
┌─────────────┐
│   Client     │
└──────┬──────┘
       │ HTTP
       ▼
┌──────────────────────────────────────────────────┐
│                  Rack Middleware                   │
│  ┌────────────┐  ┌─────────────┐                 │
│  │ Rack::Cors │  │ Rack::Attack│◄──── Redis      │
│  │  (CORS)    │  │(Rate Limit) │     (Cache)     │
│  └────────────┘  └─────────────┘                 │
└──────────────────────┬───────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────┐
│                Rails API (Puma)                    │
│                                                    │
│  ┌────────────────┐    ┌───────────────────┐      │
│  │ShortLinksController│    │ RedirectController│      │
│  │ POST /encode   │    │ GET /:code        │      │
│  │ POST /decode   │    │ (301 redirect)    │      │
│  └───────┬────────┘    └────────┬──────────┘      │
│          │                      │                  │
│          ▼                      │                  │
│  ┌──────────────────────────┐   │                  │
│  │      Form Objects         │   │                  │
│  │  ShortLinkEncodeForm     │   │                  │
│  │  ShortLinkDecodeForm     │   │                  │
│  └───────┬──────────────────┘   │                  │
│          │                      │                  │
│          ▼                      ▼                  │
│  ┌──────────────────────────────────────┐         │
│  │         ShortenerService              │         │
│  │  encode(url) → generate + persist     │         │
│  │  decode(code) → lookup                │         │
│  └───────┬──────────────────┬────────────┘         │
│          │                  │                      │
│          ▼                  ▼                      │
│  ┌──────────────┐   ┌─────────────┐               │
│  │Base62Service │   │  ShortLink Model  │               │
│  │(ID obfuscate)│   │ (ActiveRecord)              │
│  └──────────────┘   └──────┬──────┘               │
└─────────────────────────────┼─────────────────────┘
                              │
                              ▼
                       ┌─────────────┐    ┌────────────┐
                       │ PostgreSQL  │    │   Redis     │
                       │(short_links)│    │(rate limit) │
                       └─────────────┘    └────────────┘
```

## Request Flow

### Encode (`POST /encode`)

```
Client ──► Rack::Attack (rate check)
              │
              ▼
       ShortLinksController#encode
              │
              ├── ShortLinkEncodeForm.new(url:)
              │     → validates scheme, length, format
              │     → normalizes URL (strip whitespace)
              │
              ▼
       ShortenerService.encode(normalized_url)
              │
              ├── ShortLink.create!(original_url)
              │     → gets auto-increment id
              │
              ├── Base62Service.encode(id)
              │     → id XOR secret → Base62 → 6 chars
              │
              ├── code = Base62(id ^ secret)
              │     → e.g. "aUBVMQWEHq8"
              │
              ├── record.update!(short_code: code)
              │
              ▼
       Response: { short_url: "http://host/xK9m2p" }
```

### Decode (`POST /decode`)

```
Client ──► ShortLinksController#decode
              │
              ├── ShortLinkDecodeForm.new(short_url:)
              │     → extracts code from URL path
              │
              ▼
       ShortenerService.decode(code)
              │
              ├── Base62Service.decode(code) → id = decoded ^ secret
              ├── ShortLink.find_by(id: id)
              ├── verify short_code matches (tamper check)
              │
              ▼
       Response: { url: "https://original.com" } or 404
```

### Redirect (`GET /:code`)

```
Client ──► RedirectController#show
              │
              ├── ShortenerService.decode(code)
              │
              ├── found    → 301 redirect to original_url
              └── not found → 404 JSON error
```

## Component Details

### Database Schema

```
┌──────────────────────────────────────┐
│           short_links                  │
├──────────────────────────────────────┤
│ id           BIGINT  PK AUTO         │
│ original_url VARCHAR(2048) NOT NULL  │
│ short_code   VARCHAR(20)   NOT NULL  │
│ created_at   TIMESTAMP     NOT NULL  │
│ updated_at   TIMESTAMP     NOT NULL  │
├──────────────────────────────────────┤
│ INDEX unique (short_code)            │
└──────────────────────────────────────┘
```

### Redis Usage

| Purpose | Key Pattern | Data Structure |
|---------|-------------|----------------|
| Rate Limiting | `rack::attack:*` | String (counters) |

### Base62 + XOR Obfuscation Strategy

Short codes are generated deterministically from the DB auto-increment ID using XOR obfuscation + Base62 encoding.

```
ShortLink.create! → id (e.g. 123456)
       │
       ▼
  obfuscated = id XOR SECRET
       │
       ▼
  short_code = Base62(obfuscated & MASK_35).rjust(6, '0')
       → e.g. "xK9m2p"
```

**Decode (reverse):**
```
  short_code = "xK9m2p"
       │
       ▼
  obfuscated = Base62.decode("xK9m2p")
       │
       ▼
  id = obfuscated XOR SECRET
       │
       ▼
  ShortLink.find(id)  ← PK lookup, O(1)
```

**Why this approach:**
- **Zero collisions** — DB ID is unique, XOR is 1-to-1 mapping
- **No retry loop** — always succeeds on first attempt
- **Non-sequential** — XOR makes codes unpredictable
- **Fast decode** — reverse to PK, no index scan needed
- **No Redis dependency** for code generation (Redis only for rate limiting)

## Scalability & Collision Handling

### Code format

We use a 6-character Base62 code: `Base62((ID XOR secret) & MASK_35).rjust(6, '0')`.

- Code is **deterministic** from DB ID — no randomness, no collisions
- XOR with a fixed secret prevents sequential guessing
- 35-bit mask ensures output fits in 6 Base62 characters (~34 billion unique IDs)
- Can be increased to 11 chars (64-bit mask) for 62^11 ≈ 52 quadrillion capacity

### Why no collision handling is needed

```
DB auto-increment ID → unique by definition
         │
         ▼
XOR with secret → 1-to-1 mapping (bijective)
         │
         ▼
Base62 encode → deterministic string

∴ Every ID maps to exactly one unique code. No collisions possible.
```

### Database scaling

- Unique index on `short_code` for fast lookups
- Index on `original_url` for reverse lookups
- Read replicas can be added for decode-heavy workloads
- Writes go to primary DB only

### Caching layer

- Redis is used for rate limiting only
- Future: add Redis cache for hot URLs to reduce DB read load

### Horizontal scaling

```
                    ┌──────────────┐
                    │Load Balancer │
                    └──────┬───────┘
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │  App #1  │ │  App #2  │ │  App #3  │
        │(stateless)│ │(stateless)│ │(stateless)│
        └─────┬────┘ └─────┬────┘ └─────┬────┘
              │            │            │
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────────────┐
        │  Redis   │ │   PostgreSQL     │
        │(shared)  │ │   (shared)       │
        └──────────┘ └──────────────────┘
```

- Application servers are **stateless** — no session or local state
- Can scale horizontally behind a load balancer
- Shared Redis + PostgreSQL

### Future improvements (at very large scale)

- Current 6-character codes support ~34 billion links; increase to 11-char (64-bit mask) for 52 quadrillion
- Database sharding by short code prefix
- Distributed ID generators (e.g., Snowflake) for deterministic codes
- Consistent hashing for cache distribution

## Design Trade-offs

| Decision | Benefit | Cost |
|----------|---------|------|
| Base62(ID XOR secret) | Zero collisions, deterministic, fast decode via PK | Same URL gets different codes on re-encode |
| XOR obfuscation | Non-sequential codes, reversible | Secret must remain constant forever |
| DB unique constraint | Guarantees no duplicates | — |
| No URL caching (current) | Simpler architecture | Every decode hits DB |
| Stateless servers | Easy horizontal scaling | Requires shared Redis + DB |

## Rate Limiting

### Algorithm: Fixed Window Counter

Rack::Attack uses a **Fixed Window Counter** algorithm backed by Redis.

```
Timeline (1-minute windows):

  Window 1              Window 2              Window 3
  12:00:00─12:00:59     12:01:00─12:01:59     12:02:00─12:02:59
  ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
  │ counter: 0→60   │   │ counter: 0→...  │   │ counter: 0→...  │
  │ (max 60/window) │   │ (reset to 0)    │   │ (reset to 0)    │
  └─────────────────┘   └─────────────────┘   └─────────────────┘
```

**How it works:**

1. Time is divided into fixed windows (1-minute intervals)
2. Each window has a counter per IP, stored as a Redis key with TTL = window size
3. Key format: `rack::attack:<epoch / period>:<rule>:<ip>`
4. On each request: `INCR` counter → if count > limit → return `429`
5. Counter auto-expires at end of window (Redis TTL)

**Why Fixed Window Counter (not other algorithms):**

| Algorithm | Pros | Cons |
|-----------|------|------|
| **Fixed Window Counter** ✓ | Simple, 1 Redis op per request (INCR), low memory | Burst at window boundary (up to 2x limit in 2s) |
| Sliding Window Log | Exact rate limiting, no boundary burst | Stores every request timestamp, high memory |
| Sliding Window Counter | Good accuracy, moderate memory | More complex, 2+ Redis ops per request |
| Token Bucket | Smooth rate, allows controlled bursts | Requires periodic refill logic |
| Leaky Bucket | Constant output rate | Queue management complexity |

> **Trade-off:** Fixed window allows a theoretical burst at window boundary (e.g., 60 req at 12:00:59 + 60 req at 12:01:00 = 120 in 2 seconds). This is acceptable for a URL shortener — stricter control would need sliding window log at higher cost.

### Rules

```
┌────────────────────────────────────────┐
│           Rack::Attack Rules            │
├────────────────────────────────────────┤
│                                         │
│  Global:  60 requests / minute / IP    │
│  Encode:  10 requests / minute / IP    │
│                                         │
│  429 Response Headers:                  │
│  ├── RateLimit-Limit                   │
│  ├── RateLimit-Remaining               │
│  └── RateLimit-Reset                   │
│                                         │
│  Backend: Redis (via RedisCacheStore)  │
└────────────────────────────────────────┘
```

## CI/CD Pipeline

### Continuous Integration (on push/PR to `main`)

```
┌──────────────────────────────────────────────────┐
│           GitHub Actions CI                       │
│                                                    │
│  ┌──────────┐  ┌──────────┐  ┌────────────────┐ │
│  │  Lint     │  │ Security │  │     Test        │ │
│  │ RuboCop  │  │ Brakeman │  │ RSpec (66)      │ │
│  └──────────┘  └──────────┘  │ + PostgreSQL 18 │ │
│                               │ + Redis 8.6.2   │ │
│                               └────────────────┘ │
│                (all run in parallel)               │
└──────────────────────────────────────────────────┘
```

### Continuous Deployment (on git tag `v*` or manual trigger)

```
Tag push (v*) or workflow_dispatch
       │
       ▼
┌──────────────────┐    ┌──────────────────────┐
│  Build API        │    │  Build Frontend       │
│  Dockerfile       │    │  frontend/Dockerfile  │
│  → Buildx (K8s)  │    │  → Buildx (K8s)       │
│  → Push registry  │    │  → Push registry      │
└────────┬─────────┘    └──────────┬───────────┘
         │  (parallel)              │
         └──────────┬───────────────┘
                    ▼
         ┌──────────────────┐
         │     Deploy        │
         │  SSH → host       │
         │  → update .env    │
         │  → docker pull    │
         │  → docker up -d   │
         └──────────────────┘
```

### Security Scanning (on push/PR + weekly)

```
┌──────────────┐  ┌──────────────┐  ┌────────┐
│  Brakeman     │  │ Bundle Audit │  │ CodeQL │
│  (SARIF →     │  │ (gem CVEs)   │  │ (SAST) │
│   GitHub      │  │              │  │        │
│   Security)   │  │              │  │        │
└──────────────┘  └──────────────┘  └────────┘
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for full deployment details.
