# Mindora Deployment Guide

This guide covers free-tier deployment options and their SQLite persistence
trade-offs. The backend is a Flask app exporting `app` from `backend/app.py`.

## Requirements

Production must set:

- `FLASK_ENV=production`
- `SECRET_KEY` and `JWT_SECRET_KEY` — unique random values, 32+ characters
- `CORS_ORIGINS` — the exact Flutter web origin(s), comma-separated
- `SEED_DEMO_DATA=false`
- `DATABASE_PATH` — a path on persistent storage

Generate secrets locally, for example:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Run this twice and store the values in the hosting provider's secret settings.
Never commit them to the repository.

## Option A — PythonAnywhere (recommended free tier with persistent files)

PythonAnywhere free accounts provide persistent files, which suits SQLite.

1. Create a free PythonAnywhere account and open a Bash console.
2. Upload or clone this repository (or upload only the `backend/` folder).
3. Create a virtualenv and install dependencies:

   ```bash
   cd ~/Mindora/backend
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements-prod.txt
   ```

4. Create a `.env` file with production values, including:

   ```env
   FLASK_ENV=production
   SECRET_KEY=<random value>
   JWT_SECRET_KEY=<random value>
   DATABASE_PATH=/home/<username>/Mindora/backend/database/mindora.db
   CORS_ORIGINS=https://<username>.github.io
   SEED_DEMO_DATA=false
   ```

5. Create a new **Manual configuration** web app:
   - Source code: the repository folder
   - Virtualenv: `~/Mindora/backend/.venv`
   - WSGI file: import the app, for example:

     ```python
     import sys
     sys.path.insert(0, '/home/<username>/Mindora/backend')
     from app import app as application
     ```

6. Reload the web app and check:

   ```bash
   curl https://<username>.pythonanywhere.com/api/health
   ```

7. Build the Flutter web app against the public API:

   ```powershell
   D:\flutter\bin\flutter.bat build web `
     --dart-define=MINDORA_API_BASE_URL=https://<username>.pythonanywhere.com/api
   ```

   Add the Flutter web origin to `CORS_ORIGINS`.

**Limitation:** free PythonAnywhere apps may sleep and have modest CPU limits.
SQLite stays persistent because it lives on the account's file storage.

## Option B — Docker with a persistent volume (Fly.io, VPS, local server)

`backend/Dockerfile` runs Gunicorn with one worker (safer for SQLite) and expects
`/data` to be a persistent volume.

```bash
docker build -t mindora-backend ./backend
docker run -p 8000:8000 \
  -v mindora-data:/data \
  -e SECRET_KEY="<random>" \
  -e JWT_SECRET_KEY="<random>" \
  -e CORS_ORIGINS="https://your-frontend.example" \
  -e SEED_DEMO_DATA=false \
  mindora-backend
```

On Fly.io, create a volume and mount it at `/data`; keep one machine while using
SQLite. Confirm current free allowances before relying on them. If the provider
does not offer a free persistent volume, do not use it for SQLite.

## Option C — Render free web service (not suitable for SQLite as-is)

Render's free web services do **not** provide a persistent disk. The SQLite file
would be lost on redeploy or restart. Options:

1. Use PythonAnywhere instead.
2. Move to a paid Render disk (not free).
3. Migrate the database layer to managed PostgreSQL. This requires rewriting the
   SQLite-specific queries in `backend/database`, `backend/models` and the
   analytics service. It is the correct long-term choice for multiple instances,
   but it is not implemented in this project.

Do not claim a free Render deployment is production-ready for this codebase
without one of those changes.

## Health check and verification

```bash
curl https://<your-host>/api/health
```

Expected: HTTP 200 with `"status": "healthy"` and
`"database": "SQLite connected"`. If the database is unavailable the endpoint
returns 503 with `"status": "degraded"`.

## Flutter build notes

- Set the API URL at build time with
  `--dart-define=MINDORA_API_BASE_URL=https://host/api`.
- The URL can also be changed at runtime in **Settings → Server Connection**.
- For Android release builds, ensure the manifest allows the required network
  access and use HTTPS.
- Keep caregiver and user data behind HTTPS; do not deploy over plain HTTP.

## Post-deployment checklist

- [ ] `/api/health` returns 200 and database connected.
- [ ] `SEED_DEMO_DATA=false` and no demo accounts exist.
- [ ] Secrets are set in the host, not in the repository.
- [ ] `CORS_ORIGINS` lists only the real frontend origin.
- [ ] A user can register/sign in, play a game, and see progress after restart.
- [ ] A caregiver can pair with a one-time code and then loses access after unpair.
- [ ] Mood is hidden until the user enables sharing.
- [ ] Database file is on persistent storage and survives a restart.
