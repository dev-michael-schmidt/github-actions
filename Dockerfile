# syntax=docker/dockerfile:1
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# CA certs for HTTPS (boto3, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install deps first for better layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Non-root
RUN useradd -m -u 10001 appuser
COPY --chown=appuser:appuser . /app
USER appuser

EXPOSE 8080

# Healthcheck that doesn't touch S3 or do real work
HEALTHCHECK --interval=30s --timeout=2s --retries=3 CMD python - <<'PY'\nimport urllib.request, sys\ntry:\n  urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=2)\nexcept Exception:\n  sys.exit(1)\nPY

# Log-friendly Gunicorn defaults (override via env at deploy time if you like)
ENV GUNICORN_CMD_ARGS="--bind 0.0.0.0:8080 --access-logfile - --error-logfile - --log-level info --workers 1 --timeout 60 --graceful-timeout 30"

# Start
CMD ["gunicorn", "app:app"]
