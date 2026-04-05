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
│  URL length    XOR obfuscation filtering     PG auth      │
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
| Format | `[a-zA-Z0-9]{11,20}` route constraint | Only valid codes reach the controller |
| DB constraint | `NOT NULL`, unique index | Data integrity at database level |
| Model validation | Presence, uniqueness, max length 20 | Application-level defense |

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

- Codes are generated deterministically: `Base62(id XOR SECRET)` — not random
- XOR with a secret ENV variable prevents sequential code guessing
- 62^11 = ~52 quadrillion possible codes — resistant to brute force enumeration
- Collision is mathematically impossible (XOR and Base62 are bijective functions)
- Unique DB index as additional safety net

## Data Protection

### Credential Filtering

Rails `filter_parameter_logging` is configured to redact sensitive params from logs:

```
:passw, :email, :secret, :token, :_key, :crypt,
:salt, :certificate, :otp, :ssn
```

### Database Security

- Credentials stored via environment variables, not in code

### No User PII Stored

The application only stores:
- Original URLs (public information)
- Generated short codes (deterministic from ID, non-sequential)
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

- Redis used for rate limiting (Rack::Attack)
- Connection pool prevents connection exhaustion

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
| A02 Cryptographic Failures | Mitigated | [XOR obfuscation](../app/services/base62_service.rb) for codes |
| A03 Injection | Mitigated | ActiveRecord parameterized queries, [`URI.parse` validation](../app/controllers/short_links_controller.rb) |
| A04 Insecure Design | Mitigated | [Service layer](../app/services/) separation, [input validation](../app/controllers/short_links_controller.rb) |
| A05 Security Misconfiguration | Mitigated | Brakeman scans, [filtered params](../config/initializers/filter_parameter_logging.rb) |
| A06 Vulnerable Components | Mitigated | Bundler-audit ready, Brakeman scans |
| A07 Auth Failures | N/A | No authentication |
| A08 Data Integrity | Mitigated | [DB constraints, unique indexes](../db/migrate/20260405042657_create_short_links.rb) |
| A09 Logging Failures | Mitigated | [Rails logger](../config/environments/production.rb), [filtered sensitive params](../config/initializers/filter_parameter_logging.rb) |
| A10 SSRF | Mitigated | URL stored only, no server-side fetching |

## Potential Attack Vectors

### 1. Brute-force short code enumeration

Attackers may try to guess valid short URLs by brute-forcing codes.

**Mitigation:**
- Sufficiently large code space (62^11 ≈ 52 quadrillion combinations)
- Rate limiting per IP (60 req/min global, 10 req/min encode)
- Decode uses primary key lookup (O(1)), no sequential scan needed

### 2. Spam / URL abuse

Users may create malicious or spam links (phishing, malware).

**Mitigation:**
- URL validation (http/https scheme whitelist)
- Rate limit URL creation (10/min per IP)
- Future: integrate external safe browsing APIs (Google Safe Browsing)

### 3. Denial of Service (DoS)

Attackers may flood the system with requests (encode/decode).

**Mitigation:**
- Rate limiting via Rack::Attack using **Fixed Window Counter** algorithm (Redis-backed, 1 op per request)
- Stateless app servers allow horizontal scaling

### 4. Database overload

Repeated lookups or mass URL creation may overload PostgreSQL.

**Mitigation:**
- Decode reverses code to primary key — O(1) lookup, no index scan
- Database indexes on `short_code` (unique) and `original_url`
- Connection pooling prevents connection exhaustion

### 5. Collision attacks

Attackers may try to generate the same short code to overwrite existing URLs.

**Mitigation:**
- Collision is mathematically impossible — XOR and Base62 are bijective (1-to-1) functions
- Each unique DB ID maps to exactly one unique code — no retry needed
- DB unique constraint as additional safety net

### 6. SSRF (Server-Side Request Forgery)

If system fetches URLs internally, attacker may exploit internal network access.

**Mitigation:**
- The system **does NOT fetch URLs server-side** — only stores and redirects
- No HTTP client calls to user-supplied URLs

> **Key insight:** By avoiding server-side URL fetching entirely, the system eliminates the SSRF attack surface completely.

## Security Checklist

- [x] URL scheme validation (http/https only)
- [x] URL length limit (2048 chars)
- [x] Rate limiting per IP
- [x] Deterministic collision-free code generation (XOR + Base62)
- [x] Database unique constraints
- [x] Sensitive parameter filtering in logs
- [x] Brakeman static analysis (0 warnings)
- [x] RuboCop code quality checks
- [ ] Redis AUTH (production)
- [ ] CORS domain restriction (production)
- [ ] PostgreSQL SSL (production)
- [ ] WAF / DDoS protection (production)
