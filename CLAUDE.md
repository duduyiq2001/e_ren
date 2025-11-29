# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

E-Ren is a Meetup.com-style platform for university students to drive campus engagement through social events. Features include:
- University-only access (auth via school email)
- Event posting and joining (students & clubs)
- Chronological event feed
- AI-powered onboarding for personalized recommendations
- "E Score" gamification system (extroversion ranking)
- Real-time leaderboards for top students/clubs

## Architecture

### Tech Stack
- **Framework**: Ruby on Rails
- **Database**: PostgreSQL
- **Testing**: RSpec + FactoryBot + rspec-mocks
- **Containerization**: Docker + Dagger.io (via Go/TypeScript/Python SDK)
- **CI/CD**: GitHub Actions

### Modular Structure
App is organized into modules under `app/` (NOT Rails Engines):
- `app/authy/` - Authentication and authorization
- `app/posty/` - Event posting and management
- `app/notificator/` - Notifications system
- *(Add other modules as they're created)*

Each module mirrors standard Rails structure (models, controllers, services, etc.)

### Database Design
- Avoid polymorphic associations where possible
- Prefer explicit foreign keys and join tables

## Testing Strategy

### Unit Tests
- **Required** for every file
- Use RSpec with `_spec.rb` suffix
- Mock all external dependencies (use rspec-mocks)
- `spec/` directory mirrors `app/` structure
- FactoryBot for test data (use traits, sequences, associations)
- Config in `spec/support/config/`, shared examples in `spec/support/shared_examples/`

### Integration Tests
- Optional but recommended before deploy
- Test interactions between modules
- No need for database_cleaner unless using Capybara/JS tests

### Running Tests
```bash
# Via e_ren CLI (recommended - runs in Docker with live code sync)
e_ren up                    # Start containers (Rails + Postgres) - auto-builds on first run
e_ren test                  # Run all tests
e_ren test spec/models/user_spec.rb  # Run specific test file
e_ren shell                 # Open bash shell in container
e_ren logs                  # View container logs
e_ren build                 # Rebuild Docker image (only needed if Dockerfile changes)
e_ren down                  # Stop containers

# Direct RSpec (only if not using Docker)
bundle exec rspec spec/path/to/file_spec.rb
bundle exec rspec           # Run all specs
```

**Note:** The `e_ren` CLI uses Docker Compose with volume mounts, so code changes on your Mac are instantly reflected in the container. No rebuild needed!

## Docker & Compose Workflow

- **Local Development**: Docker Compose (via `e_ren` CLI) for fast iterative testing
  - Containers stay running between test runs
  - Source code mounted via volumes - changes sync instantly
  - `e_ren up` once, then `e_ren test` repeatedly
- **CI/CD**: Dagger (Python SDK) for GitHub Actions (to be configured later)
  - Reproducible builds and test runs
  - No Ruby SDK available - use Python/Go/TypeScript

## Project Organization

- **e_ren/** (this repo) - Application source code, Rails files, migrations
- **e_ren_infra/** (separate repo at `~/projects/e_ren_infra`)
  - `e_ren` CLI tool (Python) - wraps Docker Compose for dev/test
  - `docker-compose.yml` - Rails + Postgres setup with volume mounts
  - Dagger modules (for CI/CD, future)
  - Terraform configs (future)

## Development Workflow

1. **First time setup**: Run `e_ren up` to start containers
2. Make code changes in `e_ren/` (changes auto-sync to container)
3. Write unit tests for new code (mock external dependencies)
4. Run `e_ren test` or `e_ren test <file>` to verify
5. Optional: Add integration tests for module interactions
6. Commit and push - GitHub Actions will run full test suite (future)

## Memory Bank

- **2025-10-25**: Dagger.io has no official Ruby SDK - use Go/TypeScript/Python SDK to orchestrate Rails workflows. Dagger uses containers and can integrate with Dockerfiles. Requires Docker/Podman installed.
- **2025-10-25**: RSpec: spec/ directory should mirror app/ structure. Use _spec.rb suffix. Organize shared examples in spec/support/shared_examples and config in spec/support/config. Use infer_spec_type_from_file_location! for automatic type inference.
- **2025-10-25**: FactoryBot: Use traits for model variations (e.g., :admin, :published). Use sequences for unique values (sequence(:email) { |n| "person#{n}@example.com" }). Only include associations if necessary for valid object; use traits for optional associations.
- **2025-11-16**: Geocoder gem is configured for proximity search and distance calculation. TODO: Add Google Places Autocomplete (Stimulus controller + Google Maps JS API) for user-facing location input with typeahead suggestions, map preview, and automatic lat/lng population. Current setup lacks frontend address validation.
- **2025-11-22**: Set up Solid Queue for async job processing: 1) Run `bin/rails solid_queue:install` and `bin/rails db:migrate` to create queue tables in RDS, 2) Add worker process to deployment (Docker/ECS/K8s) with command `bundle exec rails solid_queue:start`, 3) Ensure worker uses same DATABASE_URL as web server
- **2025-11-28**: Changed `dependent: :destroy_async` to `dependent: :destroy` in User and EventPost models. Rails' `destroy_async` is incompatible with foreign key constraints - it queues deletion jobs that run AFTER parent delete, but FK blocks parent deletion. Use synchronous `destroy` for cascade deletion with FK constraints.
