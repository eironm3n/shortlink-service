# syntax=docker/dockerfile:1

FROM python:3.12-slim AS builder
WORKDIR /app
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1
COPY requirements.txt .
RUN python -m venv /venv \
    && /venv/bin/pip install --upgrade pip \
    && /venv/bin/pip install -r requirements.txt

FROM python:3.12-slim AS runtime
ENV PATH="/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    SHORTLINK_DATABASE_URL="sqlite:////data/shortlink.db"
RUN useradd --create-home --uid 1000 app \
    && mkdir /data && chown app:app /data
COPY --from=builder /venv /venv
WORKDIR /app
COPY app ./app
USER app
EXPOSE 8000
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request as u, sys; sys.exit(0 if u.urlopen('http://localhost:8000/healthz').status == 200 else 1)"
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
