FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_ENV=production \
    PORT=8000 \
    DATABASE_PATH=/data/mindora.db

WORKDIR /app

COPY requirements.txt requirements-prod.txt ./
RUN pip install --no-cache-dir -r requirements-prod.txt

COPY . .

# SQLite needs a writable persistent directory. Mount a volume at /data.
RUN mkdir -p /data
VOLUME ["/data"]

EXPOSE 8000

# Single worker avoids SQLite write contention. Increase only with a server DB.
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--threads", "4", "--timeout", "60", "app:app"]
