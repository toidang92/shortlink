# Setup Guide

## Prerequisites

- Ruby 3.4.7
- Docker & Docker Compose
- PostgreSQL client (for `rails db` commands)

## Quick Start

```bash
# 1. Clone and install dependencies
git clone <repo-url>
cd shortlink
bundle install

# 2. Start infrastructure
make docker-up

# 3. Create and migrate database
make db-create
make db-migrate

# 4. Start the server
make server
```

The API is available at `http://localhost:3000`.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_USERNAME` | `postgres` | PostgreSQL username |
| `DB_PASSWORD` | `postgres` | PostgreSQL password |
| `DB_NAME` | `shortlink_development` | PostgreSQL database name |
| `DB_NAME_TEST` | `shortlink_test` | PostgreSQL test database name |
| `REDIS_URL` | `redis://localhost:6379/0` | Redis connection URL |
| `REDIS_POOL_SIZE` | `10` | Redis connection pool size |
| `REDIS_POOL_TIMEOUT` | `3` | Pool checkout timeout (seconds) |
| `SHORTLINK_SECRET` | — | Hex string for XOR obfuscation (generate with `openssl rand -hex 16`) |
| `RAILS_MAX_THREADS` | `5` | Puma thread count |
| `CORS_ORIGINS` | `*` | Allowed CORS origins (comma-separated) |
| `RAILS_ENV` | `development` | Rails environment |

## API Endpoints

### Encode a URL

```bash
curl -X POST http://localhost:3000/encode \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/very/long/path"}'
```

Response:
```json
{
  "short_url": "http://localhost:3000/aUBVMQWEHq8"
}
```

### Decode a Short URL

```bash
curl -X POST http://localhost:3000/decode \
  -H "Content-Type: application/json" \
  -d '{"short_url": "http://localhost:3000/aUBVMQWEHq8"}'
```

Response:
```json
{
  "url": "https://example.com/very/long/path"
}
```

### Redirect

```bash
curl -L http://localhost:3000/aUBVMQWEHq8
# → 301 redirect to https://example.com/very/long/path
```

### Health Check

```bash
curl http://localhost:3000/up
# → 200 OK
```

## Makefile Commands

### Setup & Infrastructure

| Command | Description |
|---------|-------------|
| `make setup` | Full setup: docker + bundle + db create/migrate |
| `make docker-up` | Start PostgreSQL and Redis containers |
| `make docker-down` | Stop containers |

### Development

| Command | Description |
|---------|-------------|
| `make server` | Start Rails server |
| `make console` | Open Rails console |
| `make routes` | Show all routes |

### Database

| Command | Description |
|---------|-------------|
| `make db-create` | Create development and test databases |
| `make db-migrate` | Run pending migrations |
| `make db-reset` | Drop, create, and re-migrate |

### Quality

| Command | Description |
|---------|-------------|
| `make test` | Run all RSpec tests |
| `make test-models` | Run model specs only |
| `make test-services` | Run service specs only |
| `make test-requests` | Run request (integration) specs only |
| `make lint` | Run RuboCop linter |
| `make lint-fix` | Auto-fix RuboCop offenses |
| `make security` | Run Brakeman security scan |
| `make check` | Run lint + security + tests |

### Build

| Command | Description |
|---------|-------------|
| `make build` | Build both API and frontend Docker images |
| `make build-api` | Build API Docker image only |
| `make build-frontend` | Build frontend Docker image only |

## Running Tests

See [TESTING.md](TESTING.md) for the full testing guide.

## Docker Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| postgres | huntress/postgres-partman:18 | 5432 | Primary database |
| redis | redis:8.6.2-alpine3.23 | 6379 | Rate limiting cache |

## Project Structure

```
shortlink/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── short_links_controller.rb   # POST /encode, POST /decode
│   │   └── redirect_controller.rb      # GET /:code → 301 redirect
│   ├── form_objects/
│   │   ├── short_link_encode_form.rb   # URL validation + normalization
│   │   └── short_link_decode_form.rb   # Code extraction from short URL
│   ├── models/
│   │   └── short_link.rb               # ShortLink model with validations + strip
│   └── services/
│       ├── base62_service.rb           # Base62 + XOR obfuscation (ID encoding)
│       └── shortener_service.rb        # Encode/decode business logic
├── config/
│   ├── initializers/
│   │   ├── 01_redis.rb                 # Redis connection pool (hiredis)
│   │   ├── constants.rb                # AppConstants (MAX_URL_LENGTH, MIN_CODE_LENGTH, etc.)
│   │   ├── cors.rb                     # CORS configuration
│   │   ├── filter_parameter_logging.rb # Sensitive param filtering
│   │   └── rack_attack.rb             # Rate limiting (Fixed Window Counter)
│   ├── database.yml
│   └── routes.rb
├── db/
│   └── migrate/
│       └── *_create_short_links.rb     # short_links table with indexes
├── frontend/
│   ├── Dockerfile                      # nginx:alpine container
│   ├── nginx.conf                      # SPA routing + API proxy
│   └── index.html                      # Single-page frontend
├── spec/
│   ├── form_objects/
│   │   ├── short_link_encode_form_spec.rb
│   │   └── short_link_decode_form_spec.rb
│   ├── models/
│   │   └── short_link_spec.rb
│   ├── services/
│   │   ├── base62_service_spec.rb
│   │   └── shortener_service_spec.rb
│   └── requests/
│       ├── encode_spec.rb
│       ├── decode_spec.rb
│       ├── redirect_spec.rb
│       ├── cors_spec.rb
│       ├── rate_limit_spec.rb
│       └── health_check_spec.rb
├── .github/workflows/
│   ├── code-check.yml                  # CI: lint + security + test
│   ├── security-code-scanning.yml      # Brakeman + Bundle Audit + CodeQL
│   └── build-image-self-host.yml       # CD: build + deploy to self-hosted
├── docs/
│   ├── ARCHITECTURE.md
│   ├── BASE62_ALGORITHM.md
│   ├── DEPLOYMENT.md
│   ├── DOCKER.md
│   ├── SECURITY.md
│   ├── SETUP.md
│   └── TESTING.md
├── docker-compose.yml
├── Dockerfile
├── Makefile
└── Gemfile
```
