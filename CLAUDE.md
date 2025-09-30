# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Docker base image for Django applications with support for multiple deployment configurations. The image is published to DockerHub as `djangoflow/docker-django`.

Two variants are available:
- **Standard** (`Dockerfile`): Uses pip/traditional Python package management
  - Tags: `djangoflow/docker-django:<version>` (e.g., `3.13`)
- **UV variant** (`Dockerfile.uv`): Uses uv for faster package management (drop-in replacement)
  - Tags: `djangoflow/docker-django:<version>-uv` (e.g., `3.13-uv`)
  - All scripts at standard paths use `uv run` internally
  - Includes `manage` command in PATH for convenience (`manage migrate`, etc.)

## Image Architecture

The Dockerfile creates a Python 3.13-slim based image with:
- PostgreSQL database support (psycopg2)
- Celery task queue support
- ASGI server support (Daphne)
- WSGI server support (Gunicorn)
- Django user/group for non-root execution
- Required build tools and translation dependencies

Key environment variables:
- `PYTHONUNBUFFERED=1`
- `PYTHONPATH=/app/src:/app/src/apps`

## Entrypoint and Start Scripts

**Entrypoint** (`/entrypoint`):
- Waits for PostgreSQL to become available before proceeding
- Constructs `DATABASE_URL` from environment variables (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`)
- Uses Python with psycopg2 to verify database connectivity

**Start Scripts** (all assume Django app is at `/app` with `manage.py` at `/app/manage.py`):

### Standard Start Scripts (pip-based)

Located in root and subdirectories (`start`, `celery/worker/start`, etc.):

1. `/start` - Main Django WSGI server:
   - Runs `collectstatic --noinput`
   - Starts Gunicorn with config at `/app/src/config/gunicorn.py`
   - Binds to `0.0.0.0:5000`
   - Expects Django settings at `config.wsgi`

2. `/start-celeryworker` - Celery worker:
   - Runs `collectstatic --noinput`
   - Starts Celery worker with `--without-gossip --without-mingle` flags (workaround for celery/celery#7276)
   - Expects Celery app at `config.celery_app`

3. `/start-celerybeat` - Celery beat scheduler:
   - Starts Celery beat scheduler
   - Expects Celery app at `config.celery_app`

4. `/start-flower` - Celery Flower monitoring:
   - Starts Flower web UI
   - Uses `CELERY_BROKER_URL`, `CELERY_FLOWER_USER`, `CELERY_FLOWER_PASSWORD` environment variables
   - Expects Celery app at `config.celery_app`

5. `/start-daphne` - ASGI server:
   - Starts Daphne ASGI server
   - Binds to `0.0.0.0:5000`
   - Expects ASGI application at `config.asgi:application`

### UV Start Scripts (uv-based)

Located in `uv/` directory during build, but copied to standard paths in the UV image variant. All commands are prefixed with `uv run`:

1. `/start` - `uv run gunicorn` and `uv run python manage.py`
2. `/start-celeryworker` - `uv run celery worker`
3. `/start-celerybeat` - `uv run celery beat`
4. `/start-flower` - `uv run celery flower`
5. `/start-daphne` - `uv run daphne`
6. `manage` (in PATH) - `uv run python /app/manage.py` with arguments passed through

**Benefits of UV variant:**
- Faster dependency resolution and installation
- Better disk space efficiency with cached packages
- Works with existing `pyproject.toml` or `requirements.txt`
- Commands run via `uv run` which auto-manages virtual environments
- **Drop-in replacement**: Use `djangoflow/docker-django:3.13-uv` instead of `djangoflow/docker-django:3.13` with no other changes needed

**Usage examples in UV variant:**
```bash
# Direct manage.py commands
manage migrate
manage createsuperuser
manage collectstatic

# Same start scripts as standard variant
/start
/start-celeryworker
```

## Expected Django Project Structure

This image expects the Django project to follow this structure:
```
/app/
├── manage.py
└── src/
    ├── config/
    │   ├── wsgi.py          # WSGI application
    │   ├── asgi.py          # ASGI application
    │   ├── celery_app.py    # Celery configuration
    │   └── gunicorn.py      # Gunicorn configuration
    └── apps/                # Django apps directory
```

## Building and Publishing

**Build locally (standard):**
```bash
docker build -t djangoflow/docker-django:test .
```

**Build locally (uv variant):**
```bash
docker build -f Dockerfile.uv -t djangoflow/docker-django:test-uv .
```

**Publishing to DockerHub:**
- Automated via GitHub Actions on tag push
- Workflow: `.github/workflows/build.yml`
- Creates multi-architecture builds (via QEMU and Buildx)
- Builds **both variants** automatically:
  - Standard: `djangoflow/docker-django:<git-tag>`
  - UV variant: `djangoflow/docker-django:<git-tag>-uv`
- Requires `DOCKER_USERNAME` and `DOCKER_PASSWORD` secrets

**Manual publish:**
```bash
git tag 3.13
git push origin 3.13
```

This will automatically build and push:
- `djangoflow/docker-django:3.13` (standard)
- `djangoflow/docker-django:3.13-uv` (UV variant)

## Testing the Image

**Standard variant:**
1. Uncomment line 32 in Dockerfile: `RUN pip install psycopg2-binary celery`
2. Build the image
3. Run with appropriate environment variables for PostgreSQL connection

**UV variant:**
1. Uncomment line 37 in Dockerfile.uv: `RUN uv pip install --system psycopg2-binary celery`
2. Build the image with `-f Dockerfile.uv`
3. Run with appropriate environment variables for PostgreSQL connection

## Required Environment Variables

For all start scripts:
- `POSTGRES_USER` (defaults to 'postgres')
- `POSTGRES_PASSWORD`
- `POSTGRES_HOST`
- `POSTGRES_PORT`
- `POSTGRES_DB`

For Celery:
- `CELERY_BROKER_URL` (for all Celery services)
- `CELERY_FLOWER_USER` (for Flower only)
- `CELERY_FLOWER_PASSWORD` (for Flower only)

## Version History

- Current: Python 3.13
- Recent upgrades: 3.12 → 3.13 (commit 23ef320)
- Previous: 3.11 → 3.12 (commit 6fa9042)
