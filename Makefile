.PHONY: setup db-create db-migrate db-reset server console test test-models test-services test-requests lint lint-fix security check docker-up docker-down routes build-api build-frontend build

# Setup
setup: docker-up
	bundle install
	bundle exec rails db:create db:migrate

# Docker
docker-up:
	docker compose up -d --wait

docker-down:
	docker compose down

# Database
db-create:
	bundle exec rails db:create

db-migrate:
	bundle exec rails db:migrate

db-reset:
	bundle exec rails db:reset

# Server
server:
	bundle exec rails server

console:
	bundle exec rails console

# Test
test:
	bundle exec rspec

test-models:
	bundle exec rspec spec/models

test-services:
	bundle exec rspec spec/services

test-requests:
	bundle exec rspec spec/requests

# Lint
lint:
	bundle exec rubocop

lint-fix:
	bundle exec rubocop -A

# Security
security:
	bundle exec brakeman -q

# All checks
check: lint security test

# Build
build-api:
	docker build -t shortlink-api .

build-frontend:
	docker build -t shortlink-frontend ./frontend

build: build-api build-frontend

# Routes
routes:
	bundle exec rails routes
