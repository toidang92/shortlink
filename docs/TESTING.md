# Testing Guide

## Prerequisites

Tests require both PostgreSQL and Redis running. Start them first:

```bash
make docker-up
```

Create the test database (only needed once):

```bash
RAILS_ENV=test make db-create
RAILS_ENV=test make db-migrate
```

Or simply run `make setup` which handles everything.

## Run All Tests

```bash
make test
```

## Run by Category

```bash
# Unit tests — models (no Redis required)
make test-models

# Unit tests — services (requires PostgreSQL)
make test-services

# Integration tests — full HTTP request cycle (requires PostgreSQL + Redis)
make test-requests
```

## Run a Single File

```bash
bundle exec rspec spec/models/short_link_spec.rb
bundle exec rspec spec/services/base62_service_spec.rb
bundle exec rspec spec/requests/encode_spec.rb
```

## Run a Single Example by Line Number

```bash
bundle exec rspec spec/requests/encode_spec.rb:4
```

## Verbose Output

```bash
bundle exec rspec --format documentation
```

## Test Structure

```
spec/
├── form_objects/
│   ├── short_link_encode_form_spec.rb  # URL validation, normalization, whitespace
│   └── short_link_decode_form_spec.rb  # Code extraction, invalid URI handling
├── models/
│   └── short_link_spec.rb              # Validations: presence, length, uniqueness
├── services/
│   ├── base62_service_spec.rb          # Base62 encode/decode, round-trip, obfuscation
│   └── shortener_service_spec.rb       # Encode (persist, uniqueness, deterministic), decode
└── requests/
    ├── encode_spec.rb                  # POST /encode — valid, invalid, edge cases
    ├── decode_spec.rb                  # POST /decode — valid, not found, malformed, full flow
    ├── redirect_spec.rb                # GET /:code — 301 redirect, 404, bad format
    ├── cors_spec.rb                    # CORS preflight, headers, origin policy
    ├── rate_limit_spec.rb              # Rack::Attack throttle (global + encode)
    └── health_check_spec.rb            # GET /up — application health check
```

| Type | What it tests | External deps |
|------|--------------|---------------|
| Form object specs | Input validation, URL normalization, code extraction | None |
| Model specs | ActiveRecord validations, DB constraints | PostgreSQL |
| Service specs | Business logic, Base62 encoding, ID obfuscation | PostgreSQL |
| Request specs | Full HTTP request/response cycle, rate limiting, CORS, health check | PostgreSQL + Redis |

## Test Coverage Summary (66 examples)

### Form Object: ShortLinkEncodeForm (11 examples)

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | valid with a valid http URL | HTTP scheme accepted |
| 2 | valid with a valid https URL | HTTPS scheme accepted |
| 3 | invalid without a URL | Presence validation |
| 4 | invalid with an empty string | Blank check |
| 5 | invalid with a non-http scheme | Scheme whitelist (ftp, javascript, etc.) |
| 6 | invalid with no scheme | Missing scheme rejection |
| 7 | invalid with an invalid URI | Malformed URI handling |
| 8 | invalid when URL exceeds 2048 characters | Length limit |
| 9 | returns the normalized URL when valid | URL normalization |
| 10 | strips whitespace from the URL | Whitespace handling |
| 11 | returns nil when the form is invalid | Nil safety |

### Form Object: ShortLinkDecodeForm (8 examples)

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | valid with a short_url | Happy path |
| 2 | invalid without a short_url | Presence validation |
| 3 | invalid with an empty string | Blank check |
| 4 | extracts the code from a short URL | Code extraction |
| 5 | extracts the code from a URL with nested path | Path parsing |
| 6 | handles whitespace in the URL | Whitespace handling |
| 7 | returns nil for an invalid URI | Invalid URI safety |
| 8 | returns empty string when path is just / | Edge case |

### Model: ShortLink (6 examples)

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | valid with valid attributes | Happy path |
| 2 | invalid without original_url | Presence validation |
| 3 | invalid without short_code | Presence validation |
| 4 | invalid with original_url > 2048 chars | Length validation |
| 5 | invalid with short_code > 20 chars | Length validation |
| 6 | invalid with duplicate short_code | Uniqueness validation |

### Service: Base62Service (5 examples)

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | round-trips an ID correctly | Encode → decode = original ID |
| 2 | returns a string at least 6 characters long | Consistent code length |
| 3 | produces different codes for different IDs | Uniqueness |
| 4 | produces non-sequential codes | XOR obfuscation works |
| 5 | only contains valid Base62 characters | Character set validation |

### Service: ShortenerService (8 examples)

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | creates a persisted ShortLink record | Encode creates DB record |
| 2 | stores original URL and generates valid code | Code format Base62 |
| 3 | generates unique codes for different URLs | Uniqueness guarantee |
| 4 | generates deterministic code based on record ID | ID → code mapping |
| 5 | returns the ShortLink record for a valid code | Decode happy path |
| 6 | returns nil for an unknown code | Decode not found |
| 7 | returns nil for nil input | Decode nil safety |
| 8 | returns nil for code shorter than minimum length | Decode format validation |

### Request: POST /encode (6 examples)

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | returns short URL for valid URL | Happy path |
| 2 | persists the URL in database | DB side effect |
| 3 | returns 400 for missing URL | Missing param |
| 4 | returns 400 for invalid URL | Invalid format |
| 5 | returns 400 for non-http/https scheme | Scheme whitelist |
| 6 | returns 400 for URL > 2048 chars | Length limit |

### Request: POST /decode (6 examples)

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | returns original URL for valid short URL | Happy path |
| 2 | returns 404 for unknown short URL | Not found |
| 3 | returns 404 for missing short_url param | Missing param |
| 4 | returns 404 for malformed short_url | Invalid URI handling |
| 5 | returns 404 for empty short_url | Empty string |
| 6 | full encode-then-decode flow | End-to-end integration |

### Request: GET /:code (3 examples)

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | redirects with 301 | Happy path redirect |
| 2 | returns 404 for unknown code | Not found |
| 3 | does not match wrong format codes | Route constraint |

### Request: CORS (6 examples)

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | preflight returns OK with allowed origin | OPTIONS handling |
| 2 | allows only GET and POST methods | Method restriction |
| 3 | allows Content-Type header | Header whitelist |
| 4 | CORS headers on POST request | Regular request headers |
| 5 | CORS headers on GET request | Regular request headers |
| 6 | allows any origin | Permissive origin policy |

### Request: Rate Limiting (6 examples)

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | allows requests under global limit | Normal traffic |
| 2 | returns 429 after 60 req/min | Global throttle |
| 3 | includes rate limit headers in 429 | Response headers |
| 4 | returns JSON error body | Error format |
| 5 | returns 429 after 10 encode req/min | Encode throttle |
| 6 | non-encode requests don't count toward encode limit | Throttle isolation |

### Request: Health Check (1 example)

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | returns 200 OK | Application health |

## Run All Quality Checks

```bash
make check    # runs: rubocop → brakeman → rspec
```
