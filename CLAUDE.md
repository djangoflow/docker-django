# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Docker base image for Django applications with support for multiple deployment configurations. The image is published to DockerHub as `djangoflow/docker-django`.

- Uses uv for fast Python package management
- ASGI-only via Gunicorn + Uvicorn (handles both sync and async Django views)
- Tags: `djangoflow/docker-django:<version>` (e.g., `3.14`)
- Includes `manage` command in PATH for convenience (`manage migrate`, etc.)

## Image Architecture

The Dockerfile creates a Python 3.14-slim based image with:
- PostgreSQL database support (psycopg3)
- Celery task queue support
- ASGI server support (Gunicorn + Uvicorn)
- Django user/group for non-root execution
- uv for Python package management
- Required build tools and translation dependencies

Key environment variables:
- `PYTHONUNBUFFERED=1`
- `PYTHONPATH=/app/src:/app/src/apps`
- `PATH="/app/.venv/bin:$PATH"`
- `HOME=/app`
- `UV_CACHE_DIR=/tmp/uv-cache`

## Entrypoint and Start Scripts

**Entrypoint** (`/entrypoint`):
- Waits for PostgreSQL to become available before proceeding
- Constructs `DATABASE_URL` from environment variables (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`)
- Uses `uv run python` with psycopg3 to verify database connectivity
- DATABASE_URL uses `postgresql://` scheme

**Start Scripts** (all assume Django app is at `/app` with `manage.py` at `/app/manage.py`, all use `uv run`):

1. `/start` - Main Django ASGI server:
   - Runs `collectstatic --noinput`
   - Starts Gunicorn with Uvicorn workers (`-k uvicorn.workers.UvicornWorker`)
   - Config at `/app/src/config/gunicorn.py`
   - Binds to `0.0.0.0:5000`
   - Expects ASGI application at `config.asgi:application`

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

5. `manage` (in PATH) - `uv run python /app/manage.py` with arguments passed through

**Usage examples:**
```bash
# Direct manage.py commands
manage migrate
manage createsuperuser
manage collectstatic

# Start scripts
/start
/start-celeryworker
```

## Expected Django Project Structure

This image expects the Django project to follow this structure:
```
/app/
├── manage.py
├── pyproject.toml
└── src/
    ├── config/
    │   ├── asgi.py              # Required (for /start)
    │   ├── celery_app.py        # Celery configuration
    │   └── gunicorn.py          # Gunicorn configuration
    └── apps/                    # Django apps directory
```

## Building and Publishing

**Build locally:**
```bash
docker build -t djangoflow/docker-django:test .
```

**Publishing to DockerHub:**
- Automated via GitHub Actions on tag push
- Workflow: `.github/workflows/build.yml`
- Creates multi-architecture builds (linux/amd64, linux/arm64 via QEMU and Buildx)
- Requires `DOCKER_USERNAME` and `DOCKER_PASSWORD` secrets

**Manual publish:**
```bash
git tag 3.14
git push origin 3.14
```

## Testing the Image

1. Uncomment the test line in Dockerfile: `RUN uv pip install --system psycopg gunicorn celery uvicorn`
2. Build the image
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

- Current: Python 3.14, UV-only, ASGI-only (Gunicorn+Uvicorn), psycopg3
- Breaking change: Removed pip variant, WSGI `/start`, Daphne `/start-daphne`
- Previous: 3.13 (commit 3e12786), 3.12 → 3.13 (commit 23ef320)
