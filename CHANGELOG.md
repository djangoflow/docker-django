# Changelog

## 3.14 — Modernize: UV-only, ASGI-only, Python 3.14, psycopg3

### Added

- `manage` command in PATH — run `manage migrate`, `manage createsuperuser`, etc.
- Multi-architecture builds: `linux/amd64` and `linux/arm64`

### Changed

- **Python 3.13 → 3.14**
- **UV-only**: Single `Dockerfile` using uv for all package management (removed pip variant)
- **ASGI-only**: `/start` now runs Gunicorn with Uvicorn workers (`-k uvicorn.workers.UvicornWorker`) serving `config.asgi:application`
- **psycopg2 → psycopg3**: Entrypoint uses `psycopg` (psycopg3) for database readiness checks
- **DATABASE_URL scheme**: `postgres://` → `postgresql://`
- All scripts use `uv run` prefix
- GitHub Actions upgraded: checkout@v4, setup-qemu-action@v3, setup-buildx-action@v3, login-action@v3, build-push-action@v6

### Removed

- `Dockerfile.uv` — consolidated into single `Dockerfile`
- `uv/` directory — scripts moved to root level
- `asgi/daphne/start` (`/start-daphne`) — replaced by `/start` (Gunicorn+Uvicorn)
- Pip-based start scripts and standard (non-uv) image variant
- `-uv` tag suffix — the only image is now the uv image

### Breaking Changes

| Change | Migration |
|--------|-----------|
| No pip variant | Adopt uv (install via `pyproject.toml` or `requirements.txt`) |
| No `-uv` tag suffix | Use `djangoflow/docker-django:3.14` directly |
| `/start` is ASGI, not WSGI | Ensure `config/asgi.py` exists (Django generates this by default) |
| `/start-daphne` removed | Use `/start` instead |
| psycopg2 → psycopg3 | Install `psycopg` instead of `psycopg2`/`psycopg2-binary` |
| `config.wsgi` no longer used | Use `config.asgi:application` |

### Expected project structure

```
/app/
├── manage.py
├── pyproject.toml
└── src/
    ├── config/
    │   ├── asgi.py              # Required
    │   ├── celery_app.py        # For celery commands
    │   └── gunicorn.py          # Gunicorn config
    └── apps/
```
