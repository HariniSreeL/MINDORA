# Mindora — Project Progress

## Current phase

Phase 8: Flutter–backend integration, verification, documentation, and deployment preparation — complete.

## Audit findings (Phase 1)

- Flask backend existed under `backend/` with 29 passing pytest tests.
- Flutter app had four games, Feel Good, Mood Check-in, Progress, Caregiver Portal,
  localisation, and settings.
- Gaps found:
  - `UserAuthScreen` was orphaned and `ApiService.initialize()` was never called.
  - Caregiver Portal used hard-coded mock values.
  - Mood Check-in persisted nothing ("Skip for now" was the only action).
  - Feel Good recorded no activity.
  - Progress read only in-memory local sessions.
  - Backend seeded demo credentials in every environment, allowed wildcard CORS,
    used hard-coded development secret fallbacks, and used 4-digit non-expiring
    pairing codes.
  - Caregiver login screen pre-filled demo credentials.
  - No root README or deployment guidance.

## Completed work

### Phase 2 — Backend configuration and security

- `backend/config.py`: environment-driven secrets, CORS allow-list, demo-seed flag,
  request-size limit, login throttling, pairing TTL, and fail-fast production
  validation.
- `backend/app.py`: configuration-driven CORS, security headers, standard error
  handlers (400/401/403/404/405/409/413/429/IntegrityError/generic), and a health
  check that returns 503 when the database is unavailable.
- `backend/database/db.py`: demo seeding gated by `SEED_DEMO_DATA`, WAL mode,
  busy timeout, `schema_migrations`, and demo-only pairing code.
- Added `backend/middleware/rate_limit.py` for in-process login throttling.

### Phase 3 — Backend features and validation

- `auth_routes.py`: registration/login validation, role checks, password hash
  handling, safe responses, preferences and language updates.
- `game_routes.py`: numeric parsing, level bounds, duplicate-submission
  idempotency, session ownership, capped pagination, progression validation.
- `session_model.py`: session lookup, offset pagination, and analytics that exclude
  abandoned and merely-started sessions.
- `mood_routes.py` / `mood_model.py`: whitelisted moods and activity types,
  energy/note/duration validation, capped pagination.
- `pairing_model.py` and `caregiver_routes.py`: random `MIND-XXXX-XXXX` codes with
  15-minute expiry, single use, revoke/unpair, loved-one listing, and
  relationship-based dashboard authorization.
- `analytics_service.py`: real summaries, weekly trends, recent sessions, Feel Good
  history, consent-gated mood history, and rule-based insights.
- Added `backend/tests/test_security.py` and `test_integration_flow.py`.

### Phase 4 — Flutter API client

- Rewrote `lib/services/api_service.dart` as the single REST client:
  - Configurable base URL (`MINDORA_API_BASE_URL`, platform defaults, runtime
    setting), timeouts, centralized errors, health check.
  - Persisted token/role/name/email/user id and 401 session clearing.
  - Auth, preferences, game start/result, progress/history, mood, Feel Good,
    consent, pairing, loved ones, dashboard, unpair, revoke.
  - Offline queue in SharedPreferences (maximum 100 entries) with flush after
    sign-in and startup.
- Removed prefilled caregiver credentials and false "upcoming backend" text.

### Phase 5 — Flutter integration

- Started backend game sessions in Memory Match, Pattern Match, Word Recall, and
  Sound Recognition.
- Rewrote `lib/caregiver_portal.dart` as a stateful, backend-bound dashboard:
  loading/error/empty states, refresh, loved-one selector, pairing dialog, manage
  connections/unpair, real daily activity, game progress, mood history (respecting
  consent), weekly chart, activity calendar, engagement summary, real
  notifications, insights, and privacy notice. Removed all mock values.
- Added `GameProgress.replaceFromServer`; Progress page now hydrates from
  `GET /api/games/sessions`, shows load/error/retry/refresh states, and keeps a
  local fallback.
- Added an auth gate in `lib/main.dart`, initialized `ApiService`, and added guest
  mode plus sign-in callback support to `UserAuthScreen`.
- Mood Check-in now saves mood, optional energy and note through the API, always
  keeps a local record, and shows synced/offline confirmation.
- Feel Good logs breathing sessions and kind-message activities with sync/offline
  feedback.
- Settings now includes account status/sign-out, mood-sharing consent, one-time
  pairing code generation, caregiver-access withdrawal, server status/address,
  and backend sync for language, text size, music enabled and volume.

### Phase 6 — Tests and build

- Updated widget smoke test for the auth gate and guest flow.
- Adjusted the existing Settings test to scroll to the Language section after the
  new account section was added.
- Added opt-in live integration test `test/live_backend_test.dart`.

### Phase 7 — Documentation and deployment

- Added root `README.md` with features, setup, test commands, security,
  limitations and demo accounts.
- Rewrote `backend/README.md`, updated `backend/.env.example`, added
  `requirements-prod.txt`, `Dockerfile` and `.dockerignore`.
- Added `DEPLOYMENT.md` with free-tier options:
  - PythonAnywhere free persistent files (recommended for SQLite).
  - Docker with a persistent `/data` volume.
  - Render free web services called out as unsuitable for SQLite because they lack
    a persistent disk; PostgreSQL migration or a paid disk required.

## Modified / added files

- Flutter: `lib/services/api_service.dart`, `lib/caregiver_portal.dart`,
  `lib/progress_page.dart`, `lib/game_progress.dart`, `lib/main.dart`,
  `lib/mood_checkin.dart`, `lib/settings_page.dart`,
  `lib/screens/user_auth_screen.dart`,
  `lib/screens/caregiver_login_screen.dart`,
  `lib/screens/feel_good_screen.dart`,
  `lib/screens/pattern_match_screen.dart`,
  `lib/screens/word_recall_screen.dart`,
  `lib/screens/sound_recognition_screen.dart`, `lib/memory_game.dart`.
- Tests: `test/widget_test.dart`, `test/fixes_test.dart`,
  `test/live_backend_test.dart`.
- Backend: `backend/config.py`, `backend/app.py`, `backend/database/db.py`,
  `backend/models/session_model.py`, `backend/models/pairing_model.py`,
  `backend/routes/auth_routes.py`, `backend/routes/game_routes.py`,
  `backend/routes/mood_routes.py`, `backend/routes/caregiver_routes.py`,
  `backend/services/analytics_service.py`, `backend/middleware/rate_limit.py`,
  `backend/tests/test_security.py`, `backend/tests/test_integration_flow.py`.
- Docs/deployment: `README.md`, `DEPLOYMENT.md`, `backend/README.md`,
  `backend/.env.example`, `backend/requirements-prod.txt`,
  `backend/Dockerfile`, `backend/.dockerignore`, `.gitignore`.

## Test results (verifiable)

| Command | Result |
| --- | --- |
| `D:\flutter\bin\flutter.bat pub get` | Dependencies resolved. |
| `D:\flutter\bin\flutter.bat analyze` | No issues found. |
| `D:\flutter\bin\flutter.bat test --reporter expanded` | 7 passed, 1 skipped (opt-in live test). |
| `D:\flutter\bin\flutter.bat build web` | Built `build/web` successfully. |
| `python -m pytest backend/tests -q` | 45 passed. |
| Live test with `--dart-define=MINDORA_LIVE_BACKEND=true` against a running backend | 1 passed. |

The live test signs in as the seeded user, records a real game session, mood and
Feel Good activity, generates a pairing code, signs in as the seeded caregiver,
and verifies the dashboard response.

## Pending tasks / known limitations

- Password reset and caregiver email verification are not implemented; an
  administrator must reset accounts.
- No email or push notifications.
- ML remains optional and untrained because there is no genuine training dataset;
  the adaptive engine is rule-based.
- SQLite supports a single small instance. Multiple instances require a server
  database migration.
- Render's free web service cannot persist SQLite; use PythonAnywhere or a
  persistent volume. This is documented, not worked around silently.
- Guest mode data stays on the device and is not visible to caregivers.
- Offline queue is capped at 100 entries.

## Exact next action

No implementation step is outstanding for this project scope. To deploy, follow
`DEPLOYMENT.md` Option A (PythonAnywhere) and complete the post-deployment
checklist. Changes remain uncommitted; do not push without approval.
