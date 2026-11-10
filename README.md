# Mindora

**Cognitive Wellness Through Play** — a Flutter app with a Flask + SQLite backend
for gentle cognitive games, mood check-ins, calming activities, progress tracking,
and consent-based family caregiver support. Designed for older adults in North-East
India, with regional language options and accessible text sizing.

## Features

- Four cognitive games: Memory Match, Pattern Match, Word Recall, Sound Recognition.
- Rule-based adaptive difficulty using accuracy, mistakes, hints, completion and
  consistency. Speed alone never decides difficulty.
- Mood Check-in with optional energy level and note; private by default.
- Feel Good breathing and encouragement activities.
- Progress page hydrated from the backend, with local fallback when offline.
- Caregiver Portal showing real shared activity and weekly trends.
- One-time `MIND-XXXX-XXXX` pairing codes, 15-minute expiry, single-use, revocable.
- Mood sharing requires explicit consent and can be withdrawn at any time.
- User and caregiver authentication with hashed passwords and expiring tokens.
- Regional language selection, text-size accessibility, and background music.
- Guest mode for device-only use; sign in to sync and enable caregiver sharing.

## Project structure

```
flutter_application_1/
├── lib/                     # Flutter app (screens, services, models, theme)
│   ├── services/api_service.dart   # Central REST client, tokens, offline queue
│   ├── caregiver_portal.dart       # Backend-bound caregiver dashboard
│   ├── progress_page.dart          # Server-backed progress with local fallback
│   ├── mood_checkin.dart           # Mood save + local persistence
│   └── ...
├── test/                    # Flutter widget/unit tests + opt-in live API test
├── backend/                 # Flask API, SQLite schema, tests, Dockerfile
├── PROJECT_PROGRESS.md      # Running implementation record
└── DEPLOYMENT.md            # Free-tier deployment guide
```

## Quick start

### 1. Backend

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
python app.py
```

Health check: `http://127.0.0.1:5000/api/health`

Demo accounts are seeded in development/testing only:

| Role | Email | Password |
| --- | --- | --- |
| User | `user@mindora.org` | `MindoraUser2026` |
| Caregiver | `caregiver@mindora.org` | `MindoraCare2026` |

The seeded caregiver is paired with user id `1`. Set `SEED_DEMO_DATA=false` for
production; no demo accounts are created then.

### 2. Flutter app

```powershell
D:\flutter\bin\flutter.bat pub get
D:\flutter\bin\flutter.bat run -d chrome
```

The default API URL is `http://127.0.0.1:5000/api` on web/Windows and
`http://10.0.2.2:5000/api` on the Android emulator. Override it with:

```powershell
D:\flutter\bin\flutter.bat run -d chrome --dart-define=MINDORA_API_BASE_URL=http://192.168.1.20:5000
```

It can also be changed at runtime in **Settings → Server Connection**.

## Tests

From the repository root:

```powershell
python -m pytest backend/tests -q
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test --reporter expanded
D:\flutter\bin\flutter.bat build web
```

Live Flutter ↔ Flask integration (backend must be running):

```powershell
D:\flutter\bin\flutter.bat test --dart-define=MINDORA_LIVE_BACKEND=true test/live_backend_test.dart --reporter expanded
```

The live test signs in as the seeded user, records a real game session, mood and
Feel Good activity, generates a pairing code, then signs in as the seeded
caregiver and verifies the dashboard response.

## Security and privacy

- PBKDF2 password hashes; no plaintext passwords stored.
- JWT access tokens expire, and logout revokes the current token.
- Role-based authorization for user and caregiver routes.
- Pairing codes are random, expiring, single-use and revocable.
- Caregivers only see loved ones explicitly paired with them.
- Mood history is withheld from caregivers unless the loved one enables sharing.
- CORS allow-list, request size limits, login throttling, parameterized SQL,
  foreign keys, indexes, and hardened error responses.
- Production fails fast on development secrets or wildcard CORS.

## Deployment

Use a host that provides a persistent filesystem for SQLite, or migrate to a
server database. Render free web services do **not** include a persistent disk,
so a free Render deployment would lose data on restart. See
[`DEPLOYMENT.md`](DEPLOYMENT.md) for concrete free-tier options and limitations.

## Known limitations

- The adaptive difficulty engine is rule-based. ML is optional and is not trained
  without genuine session data.
- Password reset and caregiver email verification are not implemented; an
  administrator must reset accounts.
- No push notifications or email delivery.
- SQLite is suitable for a single small instance. Multiple app instances need a
  server database and a migration.
- Guest mode data stays on the device and cannot be seen by a caregiver.
- The offline queue keeps at most 100 pending game/mood/Feel Good records.
