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

# Unit tests — services (requires Redis for Bloom filter specs)
make test-services

# Integration tests — full HTTP request cycle (requires PostgreSQL + Redis)
make test-requests
```

## Run a Single File

```bash
bundle exec rspec spec/models/url_spec.rb
bundle exec rspec spec/services/bloom_service_spec.rb
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
├── models/
│   └── url_spec.rb                 # Validations: presence, length, uniqueness
├── services/
│   ├── bloom_service_spec.rb       # Bloom add/exist + Redis fallback behavior
│   └── shortener_service_spec.rb   # Encode (persist, bloom, uniqueness), decode
└── requests/
    ├── encode_spec.rb              # POST /encode — valid, invalid, edge cases
    ├── decode_spec.rb              # POST /decode — valid, not found, full flow
    └── redirect_spec.rb            # GET /:code — 301 redirect, 404, bad format
```

| Type | What it tests | External deps |
|------|--------------|---------------|
| Model specs | ActiveRecord validations, DB constraints | PostgreSQL |
| Service specs | Business logic, Bloom filter, Redis fallback | PostgreSQL + Redis |
| Request specs | Full HTTP request/response cycle | PostgreSQL + Redis |

## Run All Quality Checks

```bash
make check    # runs: rubocop → brakeman → rspec
```
