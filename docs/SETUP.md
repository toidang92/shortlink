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
| `REDIS_URL` | `redis://localhost:6379/0` | Redis connection URL |
| `REDIS_POOL_SIZE` | `10` | Redis connection pool size |
| `REDIS_POOL_TIMEOUT` | `3` | Pool checkout timeout (seconds) |
| `SHORTLINK_DATABASE_PASSWORD` | — | PostgreSQL password (production) |
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
  "short_url": "http://localhost:3000/a1B2c3"
}
```

### Decode a Short URL

```bash
curl -X POST http://localhost:3000/decode \
  -H "Content-Type: application/json" \
  -d '{"short_url": "http://localhost:3000/a1B2c3"}'
```

Response:
```json
{
  "url": "https://example.com/very/long/path"
}
```

### Redirect

```bash
curl -L http://localhost:3000/a1B2c3
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

## Running Tests

See [TESTING.md](TESTING.md) for the full testing guide.

## Docker Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| postgres | postgres:18 | 5432 | Primary database |
| redis | redis/redis-stack-server | 6379 | Bloom filter + rate limiting cache |

## Project Structure

```
shortlink/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── urls_controller.rb        # POST /encode, POST /decode
│   │   └── redirect_controller.rb    # GET /:code
│   ├── models/
│   │   └── url.rb                    # Url model with validations
│   └── services/
│       ├── bloom_service.rb          # Redis Bloom filter wrapper
│       └── shortener_service.rb      # Encode/decode business logic
├── config/
│   ├── initializers/
│   │   ├── 01_redis.rb               # Redis connection pool
│   │   ├── cors.rb                   # CORS configuration
│   │   └── rack_attack.rb            # Rate limiting rules
│   ├── database.yml
│   └── routes.rb
├── db/
│   └── migrate/
│       └── *_create_urls.rb          # URLs table with indexes
├── spec/
│   ├── models/url_spec.rb
│   ├── services/
│   │   ├── bloom_service_spec.rb
│   │   └── shortener_service_spec.rb
│   └── requests/
│       ├── encode_spec.rb
│       ├── decode_spec.rb
│       └── redirect_spec.rb
├── docs/
│   ├── ARCHITECTURE.md
│   ├── SECURITY.md
│   └── SETUP.md
├── docker-compose.yml
├── Makefile
└── Gemfile
```
