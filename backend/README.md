# Mindora Backend

Flask REST API for the Mindora cognitive wellness app. It powers authentication,
game session telemetry, adaptive difficulty recommendations, mood/Feel Good
tracking, and consent-based caregiver dashboards.

## Requirements

- Python 3.9+
- pip

## Local setup

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
python app.py
```

The API listens on `http://127.0.0.1:5000` by default. Health check:

```powershell
curl.exe http://127.0.0.1:5000/api/health
```

Demo data is only seeded when `SEED_DEMO_DATA=true` (development/testing).
Production must set it to `false`, and must provide strong secrets plus explicit
`CORS_ORIGINS`.

## Environment variables

| Variable | Default (development) | Notes |
| --- | --- | --- |
| `FLASK_ENV` | `development` | Use `production` to enable fail-fast validation. |
| `SECRET_KEY` | development placeholder | Required and at least 32 characters in production. |
| `JWT_SECRET_KEY` | development placeholder | Required and at least 32 characters in production. |
| `JWT_EXPIRATION_HOURS` | `72` | Token lifetime in hours. |
| `DATABASE_PATH` | `backend/database/mindora.db` | Use a persistent path in deployment. |
| `CORS_ORIGINS` | `*` | Comma-separated frontend origins in production. |
| `SEED_DEMO_DATA` | `true` in dev/test | Must be `false` in production. |
| `PORT` / `HOST` | `5000` / `0.0.0.0` | Server bind settings. |
| `LOGIN_MAX_ATTEMPTS` | `8` | Login attempts per window per account/IP. |
| `LOGIN_WINDOW_SECONDS` | `300` | Login throttling window. |
| `PAIRING_CODE_TTL_MINUTES` | `15` | Pairing code lifetime. |
| `TEST_DATABASE_PATH` | `:memory:` | Used by pytest. |

## API overview

All responses use `{ "status", "message", "data" }`. Authenticated routes need
`Authorization: Bearer <token>`.

- `POST /api/auth/register`, `POST /api/auth/login`
- `POST /api/auth/caregiver/login`
- `GET /api/auth/me`, `POST /api/auth/logout`
- `PUT /api/auth/language`, `GET|PUT /api/auth/preferences`
- `POST /api/games/sessions/start`
- `POST /api/games/sessions/<id>/result`
- `POST /api/games/session` (legacy single-call submission)
- `GET /api/games/sessions`, `GET /api/games/progress`, `GET /api/games/progression`
- `PUT /api/games/progression`
- `POST|GET /api/wellness/mood`, `POST|GET /api/wellness/feel-good`
- `PUT /api/wellness/consent`
- `GET /api/caregiver/loved-ones`, `GET /api/caregiver/dashboard[/<user_id>]`
- `POST /api/caregiver/pair`, `DELETE /api/caregiver/pair/<user_id>`
- `DELETE /api/caregiver/pairings`
- `POST /api/caregiver/generate-code`
- `GET /api/ml/adaptive-state`, `POST /api/ml/predict-difficulty`

## Security model

- PBKDF2 password hashing via Werkzeug.
- Signed JWT access tokens with expiry; logout revokes the token.
- Role checks on user and caregiver routes.
- Pairing codes are random (`secrets`), expire after 15 minutes, are single-use,
  and can be revoked by either side. Codes are never logged by the API.
- Mood history is only included in a caregiver dashboard while the loved one has
  explicitly enabled mood sharing.
- Parameterized SQLite queries, foreign keys, and indexes.
- Request size limit, login throttling, CORS allow-list, and security headers.
- Production refuses to start with development secrets or wildcard CORS.

## Tests

```powershell
# from the repository root
python -m pytest backend/tests -q
```

Tests use an in-memory SQLite database and seeded demo fixtures.

## Demo accounts (development/testing only)

| Role | Email | Password |
| --- | --- | --- |
| User | `user@mindora.org` | `MindoraUser2026` |
| Caregiver | `caregiver@mindora.org` | `MindoraCare2026` |

The seeded caregiver is paired with user id `1`. These accounts are not created
when `SEED_DEMO_DATA=false`.

## Deployment

See [`../DEPLOYMENT.md`](../DEPLOYMENT.md). For SQLite persistence, mount a
writable volume at `/data` and set `DATABASE_PATH=/data/mindora.db`.
