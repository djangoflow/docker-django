FROM python:3.12-slim-buster

ENV PYTHONUNBUFFERED 1
ENV PYTHONPATH=/app/src:/app/src/apps

RUN apt-get update \
  # dependencies for building Python packages
  && apt-get install -y build-essential \
  # psycopg2 dependencies
  && apt-get install -y libpq-dev \
  # Translations dependencies
  && apt-get install -y gettext curl git \
  # cleaning up unused files
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/apt/lists/*

RUN addgroup --system django \
    && adduser --system --ingroup django django

COPY --chown=django:django ./entrypoint /entrypoint
COPY --chown=django:django ./start /start
COPY --chown=django:django ./celery/worker/start /start-celeryworker
COPY --chown=django:django ./celery/beat/start /start-celerybeat
COPY --chown=django:django ./celery/flower/start /start-flower
COPY --chown=django:django ./asgi/daphne/start /start-daphne

RUN mkdir /app && chown django:django /app

WORKDIR /app

# Uncomment these line for testing
# RUN pip install psycopg2-binary celery

ENTRYPOINT ["/entrypoint"]
