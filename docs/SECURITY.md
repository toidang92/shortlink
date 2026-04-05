# Security

## Threat Model

```
┌───────────────────────────────────────────────────────────┐
│                    Attack Surface                          │
│                                                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │  Input    │  │  Abuse   │  │  Data    │  │  Infra   │ │
│  │Validation │  │Prevention│  │ Exposure │  │ Security │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘ │
│       │              │              │              │       │
│       ▼              ▼              ▼              ▼       │
│  URL scheme    Rate limiting   Credential    Redis auth   │
│  URL length    Bloom filter    filtering     PG auth      │
│  URI parsing   Code entropy    No PII logs   CORS policy  │
└───────────────────────────────────────────────────────────┘
```

## Input Validation

### URL Validation

| Check | Implementation | Why |
|-------|---------------|-----|
| Scheme whitelist | Only `http://` and `https://` allowed | Prevents `javascript:`, `data:`, `file:` injection |
| Length limit | Max 2048 characters | Prevents storage abuse and buffer issues |
| URI parsing | `URI.parse` with rescue on `InvalidURIError` | Rejects malformed URLs |
| Blank check | `url.blank?` guard | Prevents empty submissions |

### Short Code Validation

| Check | Implementation | Why |
|-------|---------------|-----|
| Format | `[a-zA-Z0-9]{6}` route constraint | Only valid codes reach the controller |
| DB constraint | `NOT NULL`, unique index | Data integrity at database level |
| Model validation | Presence, uniqueness, max length 10 | Application-level defense |

## Abuse Prevention

### Rate Limiting (Rack::Attack)

```
Incoming Request
       │
       ▼
  ┌─────────────────────┐
  │ Check: req/ip        │─── 60/min exceeded? ──► 429 + headers
  │ (all endpoints)      │
  └──────────┬──────────┘
             │ pass
             ▼
  ┌─────────────────────┐
  │ Check: encode/ip     │─── 10/min exceeded? ──► 429 + headers
  │ (POST /encode only)  │
  └──────────┬──────────┘
             │ pass
             ▼
       Controller
```

- Rate limit state stored in Redis (fast, shared across processes)
- Response includes `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset` headers
- Stricter limit on `/encode` to prevent database flooding

### Code Generation Security

- Uses `SecureRandom.alphanumeric(6)` — cryptographically secure
- 62^6 = ~56.8 billion possible codes — resistant to brute force enumeration
- Bloom filter prevents collision-based DoS on code generation
- Unique DB index as final safety net

## Data Protection

### Credential Filtering

Rails `filter_parameter_logging` is configured to redact sensitive params from logs:

```
:passw, :email, :secret, :token, :_key, :crypt,
:salt, :certificate, :otp, :ssn
```

### Database Security

- Credentials stored via environment variables, not in code
- `config/master.key` excluded from git (`.gitignore`)
- `config/credentials.yml.enc` encrypted at rest

### No User PII Stored

The application only stores:
- Original URLs (public information)
- Generated short codes (random, non-identifiable)
- Timestamps

No user accounts, sessions, cookies, or tracking.

## Infrastructure Security

### CORS Policy

Currently configured as permissive (`origins "*"`) for development.

**Production recommendation:**
```ruby
origins 'https://yourdomain.com'
```

### Redis

- Redis Stack Server used for Bloom filter support
- Connection pool prevents connection exhaustion
- hiredis driver (C-based) — no known Ruby-layer vulnerabilities

**Production recommendation:**
- Enable Redis AUTH (`requirepass`)
- Use TLS for Redis connections
- Bind to localhost or private network only

### PostgreSQL

- Default config uses Unix socket (no network exposure in dev)
- Production uses environment variable for password

**Production recommendation:**
- Use SSL connections (`sslmode: require`)
- Restrict user permissions to minimum required
- Enable `log_connections` and `log_disconnections`

## OWASP Top 10 Coverage

| Risk | Status | Implementation |
|------|--------|---------------|
| A01 Broken Access Control | N/A | No auth required (public service) |
| A02 Cryptographic Failures | Mitigated | SecureRandom for codes, encrypted credentials |
| A03 Injection | Mitigated | ActiveRecord parameterized queries, URI.parse validation |
| A04 Insecure Design | Mitigated | Service layer separation, input validation |
| A05 Security Misconfiguration | Mitigated | Brakeman scans, filtered params |
| A06 Vulnerable Components | Mitigated | Bundler-audit ready, Brakeman scans |
| A07 Auth Failures | N/A | No authentication |
| A08 Data Integrity | Mitigated | DB constraints, unique indexes |
| A09 Logging Failures | Mitigated | Rails logger, filtered sensitive params |
| A10 SSRF | Mitigated | URL stored only, no server-side fetching |

## Security Checklist

- [x] URL scheme validation (http/https only)
- [x] URL length limit (2048 chars)
- [x] Rate limiting per IP
- [x] Cryptographically secure code generation
- [x] Database unique constraints
- [x] Sensitive parameter filtering in logs
- [x] Encrypted credentials
- [x] Brakeman static analysis (0 warnings)
- [x] RuboCop code quality checks
- [ ] Redis AUTH (production)
- [ ] CORS domain restriction (production)
- [ ] PostgreSQL SSL (production)
- [ ] WAF / DDoS protection (production)
