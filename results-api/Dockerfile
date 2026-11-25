# ── Stage 1: build ──────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /app

# Install dependencies into a local directory
COPY requirements.txt .
RUN pip install --upgrade pip --quiet && \
    pip install --quiet --prefix=/install -r requirements.txt

# ── Stage 2: runtime ─────────────────────────────────────────
FROM python:3.12-slim

WORKDIR /app

# CVE-2026-124851: python:3.12-slim ships libzstd1 1.5.7+dfsg-1; the fix is
# 1.5.7+dfsg-1+deb13u1. Remove this step once the base image includes it.
RUN apt-get update \
    && apt-get install -y --no-install-recommends --only-upgrade libzstd1 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application source
COPY --chown=appuser:appgroup . .

# Switch to non-root user
USER appuser

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]