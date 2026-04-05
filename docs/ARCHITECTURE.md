# Architecture

## System Overview

Shortlink is a URL shortening service built with Rails 8.1 API, PostgreSQL, and Redis Bloom Filter.

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
│  │ UrlsController │    │ RedirectController│      │
│  │ POST /encode   │    │ GET /:code        │      │
│  │ POST /decode   │    │ (301 redirect)    │      │
│  └───────┬────────┘    └────────┬──────────┘      │
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
│  │ BloomService │   │  Url Model  │               │
│  │ (Redis BF)   │   │ (ActiveRecord)              │
│  └──────┬───────┘   └──────┬──────┘               │
└─────────┼──────────────────┼──────────────────────┘
          │                  │
          ▼                  ▼
   ┌────────────┐    ┌─────────────┐
   │   Redis     │    │ PostgreSQL  │
   │ Bloom Filter│    │   (urls)    │
   └────────────┘    └─────────────┘
```

## Request Flow

### Encode (`POST /encode`)

```
Client ──► Rack::Attack (rate check)
              │
              ▼
       UrlsController#encode
              │
              ├── validate URL (scheme, length)
              │
              ▼
       ShortenerService.encode
              │
              ├── generate_code (loop)
              │     │
              │     ├── SecureRandom.alphanumeric(6)
              │     ├── BloomService.might_exist?(code)
              │     │     │
              │     │     ├── NO  → use this code ✓
              │     │     └── YES → check DB (false positive?)
              │     │           │
              │     │           ├── NOT in DB → use this code ✓
              │     │           └── IN DB → retry loop
              │     │
              ├── Url.create!(original_url, short_code)
              ├── BloomService.add(code)
              │
              ▼
       Response: { short_url: "http://host/abc123" }
```

### Decode (`POST /decode`)

```
Client ──► UrlsController#decode
              │
              ├── extract code from short_url
              ▼
       ShortenerService.decode
              │
              ├── Url.find_by(short_code: code)
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
│              urls                      │
├──────────────────────────────────────┤
│ id           BIGINT  PK AUTO         │
│ original_url VARCHAR(2048) NOT NULL  │
│ short_code   VARCHAR(10)   NOT NULL  │
│ created_at   TIMESTAMP     NOT NULL  │
│ updated_at   TIMESTAMP     NOT NULL  │
├──────────────────────────────────────┤
│ INDEX unique (short_code)            │
│ INDEX        (original_url)          │
└──────────────────────────────────────┘
```

### Redis Usage

| Purpose | Key Pattern | Data Structure |
|---------|-------------|----------------|
| Bloom Filter | `shortlink:bloom` | RedisBloom `BF.*` |
| Rate Limiting | `rack::attack:*` | String (counters) |

### Connection Pooling

```
┌──────────────────────────────┐
│       Connection Pool         │
│  (size: 10, timeout: 3s)     │
│                               │
│  ┌─────┐ ┌─────┐ ┌─────┐    │
│  │Redis│ │Redis│ │Redis│ ... │
│  │conn │ │conn │ │conn │    │
│  └─────┘ └─────┘ └─────┘    │
│                               │
│  Driver: hiredis (C-based)   │
└──────────────────────────────┘
```

### Bloom Filter Strategy

The Bloom filter is a probabilistic data structure that answers "definitely not in set" or "possibly in set."

```
New code generated
       │
       ▼
  BF.EXISTS code
       │
       ├── 0 (definitely not exists)
       │   └── Use code immediately (skip DB query) ✓
       │
       └── 1 (possibly exists — false positive rate ~1%)
           │
           ▼
     DB.exists?(short_code: code)
           │
           ├── false → Use code (was a false positive) ✓
           └── true  → Generate new code, retry
```

**Why this matters at scale:**
- Without Bloom: every code generation = 1 DB query
- With Bloom: ~99% of code generations = 0 DB queries
- Bloom filter uses ~1.2 bytes per entry (vs full DB lookup)

## Rate Limiting

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
