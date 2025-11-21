# E-Ren

[![Build Status](https://jenkins.yiqundu.com/buildStatus/icon?job=e_ren-ci%2Fmain)](https://jenkins.yiqundu.com/job/e_ren-ci/job/main/)

A configurable, customizable solution for student-run Meetup.com-like sites on college campuses!

## Features
- University-only access (school email authentication)
- Event posting and registration
- E-score gamification system
- Real-time leaderboards
- AI-powered event recommendations

## Prerequisites
- Ruby 3.4.1
- PostgreSQL 16+
- Node.js (for asset compilation)
- Docker & Docker Compose (optional, for containerized development)

## Setup
trigger pr pipeline test
### Option 1: Automated Setup (Recommended)
```bash
bin/setup
```

This will:
1. Install dependencies (`bundle install`)
2. Create database
3. Run all migrations
4. Seed sample data
5. Start development server

### Option 2: Manual Setup
```bash
# Install dependencies
bundle install

# Create database and run migrations
rails db:create
rails db:migrate

# Load seed data (optional, creates sample users/events)
rails db:seed

# Start server
rails server
```

### Option 3: Docker Setup (via e_ren_infra)
```bash
# From ~/projects/e_ren_infra

# First time setup (or just run: ./setup.sh):
# 1. Start PostgreSQL container
docker-compose up -d db

# 2. Wait a few seconds for Postgres to be ready, then install gems and create databases
docker-compose run --rm rails bash -c "bundle install && rails db:prepare"

# 3. Start Rails server
docker-compose up rails

# Subsequent runs:
docker-compose up  # Just start everything

# Other commands:
docker-compose run --rm rails bash -c "bundle install && rspec"                    # Run tests
docker-compose run --rm rails bash -c "bundle install && rails console"            # Open Rails console
docker-compose exec rails bash                                                     # Open bash shell (if container is running)
docker-compose down                                                                # Stop all containers
```

**Note:** This creates TWO databases:
- `e_ren_development` - for development server
- `e_ren_test` - for running tests (automatically managed by RSpec)

## Database Migrations

The app uses **two separate databases**:
- `e_ren_development` - Development server data
- `e_ren_test` - Test data (auto-created/managed by RSpec)

### Development

**Local (non-Docker):**
```bash
# Create a new migration
rails generate migration AddFieldToModel field:type

# Run pending migrations (both dev and test databases)
rails db:migrate

# Rollback last migration
rails db:rollback

# Reset database (drop, create, migrate, seed)
rails db:reset
```

**Docker:**
```bash
# Create a new migration (from ~/projects/e_ren)
rails generate migration AddFieldToModel field:type

# Run migrations in Docker (from ~/projects/e_ren_infra)
docker-compose run --rm rails bash -c "bundle install && rails db:migrate"

# Reset database
docker-compose run --rm rails bash -c "bundle install && rails db:reset"
```

### Production
**⚠️ ALWAYS backup before running production migrations:**
```bash
# 1. Backup database
pg_dump e_ren_production > backup_$(date +%Y%m%d_%H%M%S).sql

# 2. Run migration
rails db:migrate RAILS_ENV=production

# 3. If something breaks, restore backup
psql e_ren_production < backup_20250128_143022.sql
```

## Running Tests

**Local (non-Docker):**
```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec
```

**Docker:**
```bash
# From ~/projects/e_ren_infra
docker-compose run --rm rails bash -c "bundle install && rspec"

# Run specific test
docker-compose run --rm rails bash -c "bundle install && rspec spec/models/user_spec.rb"
```

## Troubleshooting

### Docker: "database does not exist" or connection errors
```bash
# Postgres might not be ready yet. Wait 5-10 seconds after `docker-compose up -d db`
# Then run:
docker-compose run --rm rails bash -c "bundle install && rails db:prepare"

# Or check Postgres logs:
docker-compose logs db
```

### Rails: "PG::ConnectionBad"
```bash
# Ensure PostgreSQL is running:
# Local: brew services list (macOS)
# Docker: docker-compose ps
```

### Migrations out of sync
```bash
# Check migration status
rails db:migrate:status

# Reset everything (⚠️ destroys data)
rails db:reset
```

## Time Zone Configuration
Application is configured for **Central Time (US & Canada)**.
All times displayed in views and stored in the database use this timezone.

## Project Structure
```
app/
├── authy/          # Authentication & authorization
├── posty/          # Event posting & management
├── notificator/    # Notifications system
├── models/         # ActiveRecord models
├── controllers/    # Request handlers
└── views/          # ERB templates (Tailwind CSS)
```

## Environment Variables
Create a `.env` file (not committed to git):
```bash
DATABASE_URL=postgresql://localhost/e_ren_development
SECRET_KEY_BASE=your_secret_key_here
```

## Contributing
1. Create feature branch
2. Write tests
3. Implement feature
4. Run tests (`bundle exec rspec`)
5. Submit PR

## Deployment
See `../e_ren_infra` repository for Docker Compose and deployment configurations.

**Important:** Production migrations require manual approval and database backup.
