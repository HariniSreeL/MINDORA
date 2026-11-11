"""Regression tests for game-session persistence.

These cover the real-world failure modes that made completed games disappear:
- the result arriving after the next level already started
- duplicate starts / duplicate result submissions
- retries through the fallback /session endpoint
- cleanup only abandoning stale sessions
- caregiver analytics reading the same database
"""
import json

from app import create_app
from database.db import get_db_connection


def _json(resp):
    return json.loads(resp.data)


def _fetchone(sql, params=()):
    conn = get_db_connection()
    try:
        row = conn.execute(sql, params).fetchone()
        return dict(row) if row else None
    finally:
        conn.close()


def _fetchall(sql, params=()):
    conn = get_db_connection()
    try:
        return [dict(row) for row in conn.execute(sql, params).fetchall()]
    finally:
        conn.close()


def _start(client, headers, game_id='memory_match', level=1, client_session_id=None):
    payload = {'game_id': game_id, 'level': level}
    if client_session_id is not None:
        payload['client_session_id'] = client_session_id
    return client.post('/api/games/sessions/start', json=payload, headers=headers)


def _result(client, headers, session_id, **overrides):
    payload = {
        'correct_answers': 4,
        'incorrect_answers': 1,
        'hints_used': 0,
        'duration_seconds': 30,
        'completed': True,
        'score': 90,
        'level': 1,
    }
    payload.update(overrides)
    return client.post(f'/api/games/sessions/{session_id}/result', json=payload, headers=headers)


def test_result_is_written_to_game_sessions_and_game_results(client, auth_headers):
    start = _start(client, auth_headers, client_session_id='persist-write-001')
    assert start.status_code == 201
    session_id = _json(start)['data']['session']['id']

    result = _result(client, auth_headers, session_id, client_session_id='persist-write-001')
    assert result.status_code == 201

    persisted = _fetchone('SELECT * FROM game_sessions WHERE id = ?', (session_id,))
    assert persisted['status'] == 'completed'
    assert persisted['completed'] == 1
    assert persisted['score'] == 90
    assert persisted['client_session_id'] == 'persist-write-001'

    result_row = _fetchone('SELECT * FROM game_results WHERE session_id = ?', (session_id,))
    assert result_row is not None
    assert result_row['correct_answers'] == 4
    assert result_row['incorrect_answers'] == 1

    progress = _fetchone(
        'SELECT games_played FROM game_progress WHERE user_id = ? AND game_id = ?',
        (1, 'memory_match'),
    )
    assert progress['games_played'] == 1


def test_result_arriving_after_next_level_start_is_not_dropped(client, auth_headers):
    """The next level's start must not abandon the session awaiting its result."""
    first = _start(client, auth_headers, level=1, client_session_id='race-level-1')
    first_id = _json(first)['data']['session']['id']
    second = _start(client, auth_headers, level=2, client_session_id='race-level-2')
    second_id = _json(second)['data']['session']['id']
    assert first_id != second_id

    # Level 1 finishes after level 2 already started.
    result = _result(client, auth_headers, first_id, level=1, correct_answers=5)
    assert result.status_code == 201
    assert _json(result)['data']['session']['status'] == 'completed'

    first_row = _fetchone('SELECT * FROM game_sessions WHERE id = ?', (first_id,))
    assert first_row['status'] == 'completed'
    assert _fetchone('SELECT * FROM game_results WHERE session_id = ?', (first_id,)) is not None
    assert _fetchone('SELECT status FROM game_sessions WHERE id = ?', (second_id,))['status'] == 'started'


def test_only_stale_started_sessions_are_abandoned(client, auth_headers):
    start = _start(client, auth_headers, client_session_id='stale-old-session')
    old_id = _json(start)['data']['session']['id']

    conn = get_db_connection()
    try:
        with conn:
            conn.execute(
                "UPDATE game_sessions SET started_at = datetime('now', '-600 seconds') WHERE id = ?",
                (old_id,),
            )
    finally:
        conn.close()

    fresh = _start(client, auth_headers, client_session_id='stale-new-session')
    fresh_id = _json(fresh)['data']['session']['id']

    assert _fetchone('SELECT status FROM game_sessions WHERE id = ?', (old_id,))['status'] == 'abandoned'
    assert _fetchone('SELECT status FROM game_sessions WHERE id = ?', (fresh_id,))['status'] == 'started'


def test_late_result_can_complete_a_session_cleaned_up_as_abandoned(client, auth_headers):
    start = _start(client, auth_headers, client_session_id='late-result-session')
    session_id = _json(start)['data']['session']['id']

    conn = get_db_connection()
    try:
        with conn:
            conn.execute(
                "UPDATE game_sessions SET status = 'abandoned', "
                "started_at = datetime('now', '-600 seconds') WHERE id = ?",
                (session_id,),
            )
    finally:
        conn.close()

    result = _result(client, auth_headers, session_id, correct_answers=3)
    assert result.status_code == 201
    assert _json(result)['data']['session']['status'] == 'completed'
    assert _fetchone('SELECT * FROM game_results WHERE session_id = ?', (session_id,)) is not None


def test_duplicate_start_with_same_client_id_returns_one_session(client, auth_headers):
    first = _start(client, auth_headers, client_session_id='dup-start-key')
    second = _start(client, auth_headers, client_session_id='dup-start-key')
    assert first.status_code == 201
    assert second.status_code == 201
    assert _json(first)['data']['session']['id'] == _json(second)['data']['session']['id']

    rows = _fetchall(
        "SELECT id FROM game_sessions WHERE user_id = 1 AND client_session_id = 'dup-start-key'"
    )
    assert len(rows) == 1


def test_duplicate_result_submission_does_not_double_count(client, auth_headers):
    start = _start(client, auth_headers, client_session_id='dup-result-key')
    session_id = _json(start)['data']['session']['id']

    first = _result(client, auth_headers, session_id, client_session_id='dup-result-key')
    second = _result(client, auth_headers, session_id, client_session_id='dup-result-key')
    assert first.status_code == 201
    assert second.status_code == 200
    assert _json(second)['data']['duplicate'] is True

    assert len(_fetchall('SELECT * FROM game_results WHERE session_id = ?', (session_id,))) == 1
    progress = _fetchone(
        'SELECT games_played FROM game_progress WHERE user_id = 1 AND game_id = ?',
        ('memory_match',),
    )
    assert progress['games_played'] == 1


def test_fallback_endpoint_dedupes_by_client_id(client, auth_headers):
    payload = {
        'game_id': 'word_recall',
        'level': 1,
        'duration_seconds': 20,
        'correct_answers': 3,
        'incorrect_answers': 1,
        'completed': True,
        'score': 85,
        'client_session_id': 'fallback-dup-key',
    }
    first = client.post('/api/games/session', json=payload, headers=auth_headers)
    second = client.post('/api/games/session', json=payload, headers=auth_headers)
    assert first.status_code == 201
    assert second.status_code == 201
    assert _json(first)['data']['session']['id'] == _json(second)['data']['session']['id']

    sessions = _fetchall("SELECT * FROM game_sessions WHERE client_session_id = 'fallback-dup-key'")
    assert len(sessions) == 1
    assert _fetchone('SELECT * FROM game_results WHERE session_id = ?', (sessions[0]['id'],)) is not None
    progress = _fetchone(
        'SELECT games_played FROM game_progress WHERE user_id = 1 AND game_id = ?',
        ('word_recall',),
    )
    assert progress['games_played'] == 1


def test_fallback_completes_matching_started_session(client, auth_headers):
    start = _start(client, auth_headers, game_id='pattern_match', level=2,
                   client_session_id='fallback-started-key')
    session_id = _json(start)['data']['session']['id']

    fallback = client.post('/api/games/session', json={
        'game_id': 'pattern_match',
        'level': 2,
        'duration_seconds': 25,
        'correct_answers': 4,
        'incorrect_answers': 0,
        'completed': True,
        'score': 100,
        'client_session_id': 'fallback-started-key',
    }, headers=auth_headers)
    assert fallback.status_code == 201
    assert _json(fallback)['data']['session']['id'] == session_id

    sessions = _fetchall("SELECT * FROM game_sessions WHERE client_session_id = 'fallback-started-key'")
    assert len(sessions) == 1
    assert sessions[0]['id'] == session_id
    assert sessions[0]['status'] == 'completed'


def test_result_retry_with_stale_session_id_resolves_by_client_key(client, auth_headers):
    start = _start(client, auth_headers, client_session_id='retry-stale-id-key')
    session_id = _json(start)['data']['session']['id']

    # A queued retry may carry an old/incorrect id; the client key must resolve
    # it to the real session instead of returning 404.
    retry = client.post('/api/games/sessions/999999/result', json={
        'game_id': 'memory_match',
        'level': 1,
        'correct_answers': 4,
        'incorrect_answers': 1,
        'duration_seconds': 30,
        'completed': True,
        'score': 90,
        'client_session_id': 'retry-stale-id-key',
    }, headers=auth_headers)
    assert retry.status_code == 201
    assert _json(retry)['data']['session']['id'] == session_id
    assert _fetchone('SELECT status FROM game_sessions WHERE id = ?', (session_id,))['status'] == 'completed'


def test_caregiver_dashboard_reads_completed_sessions(client, auth_headers, caregiver_headers):
    start = _start(client, auth_headers, game_id='sound_recognition', level=1,
                   client_session_id='caregiver-view-key')
    session_id = _json(start)['data']['session']['id']
    _result(client, auth_headers, session_id, correct_answers=4, score=95)

    dashboard = client.get('/api/caregiver/dashboard/1', headers=caregiver_headers)
    assert dashboard.status_code == 200
    data = _json(dashboard)['data']
    assert data['summary']['total_games_played'] == 1
    assert data['recent_activities'][0]['game_id'] == 'sound_recognition'


def test_health_reports_database_file(client):
    resp = client.get('/api/health')
    assert resp.status_code == 200
    body = _json(resp)['data']
    assert body['database_file']
    assert body['database_file'].endswith('.sqlite')


def test_history_survives_application_restart(app, client):
    """A brand-new server process on the same SQLite file still returns progress."""
    email = 'restart-user@example.org'
    password = 'SecurePassword123'
    register = client.post('/api/auth/register', json={
        'name': 'Restart User',
        'email': email,
        'password': password,
        'preferred_language': 'English',
    })
    assert register.status_code == 201
    user_id = _json(register)['data']['user']['id']
    headers = {'Authorization': f"Bearer {_json(register)['data']['token']}"}

    start = _start(client, headers, client_session_id='restart-proof-1')
    session_id = _json(start)['data']['session']['id']
    assert _result(client, headers, session_id, correct_answers=4, score=88).status_code == 201

    # Simulate closing and reopening the application: new app instance, same DB.
    db_path = app.config['DATABASE_PATH']
    restarted = create_app('testing', database_path=db_path)
    restarted_client = restarted.test_client()
    login = restarted_client.post('/api/auth/login', json={'email': email, 'password': password})
    assert login.status_code == 200
    restarted_headers = {'Authorization': f"Bearer {_json(login)['data']['token']}"}

    history = restarted_client.get('/api/games/sessions', headers=restarted_headers)
    assert history.status_code == 200
    sessions = _json(history)['data']['sessions']
    assert len(sessions) == 1
    assert sessions[0]['id'] == session_id
    assert sessions[0]['user_id'] == user_id
    assert sessions[0]['status'] == 'completed'
    assert sessions[0]['client_session_id'] == 'restart-proof-1'

    progress = restarted_client.get('/api/games/progress', headers=restarted_headers)
    summary = _json(progress)['data']['summary']['overview']
    assert summary['total_games'] == 1
    assert summary['total_matches'] == 4


def test_history_is_scoped_to_the_authenticated_user(client):
    first = client.post('/api/auth/register', json={
        'name': 'First User',
        'email': 'scope-first@example.org',
        'password': 'SecurePassword123',
        'preferred_language': 'English',
    })
    assert first.status_code == 201
    first_id = _json(first)['data']['user']['id']
    first_headers = {'Authorization': f"Bearer {_json(first)['data']['token']}"}

    start = _start(client, first_headers, client_session_id='scope-first-key')
    _result(client, first_headers, _json(start)['data']['session']['id'])

    second = client.post('/api/auth/register', json={
        'name': 'Second User',
        'email': 'scope-second@example.org',
        'password': 'SecurePassword123',
        'preferred_language': 'English',
    })
    assert second.status_code == 201
    second_headers = {'Authorization': f"Bearer {_json(second)['data']['token']}"}

    own = _json(client.get('/api/games/sessions', headers=first_headers))['data']['sessions']
    assert len(own) == 1
    assert own[0]['user_id'] == first_id

    other = _json(client.get('/api/games/sessions', headers=second_headers))['data']['sessions']
    assert other == []


def test_caregiver_dashboard_tracks_newly_completed_sessions(client, auth_headers, caregiver_headers):
    def complete(game_id, correct, score):
        start = _start(client, auth_headers, game_id=game_id,
                       client_session_id=f'caregiver-refresh-{game_id}')
        result = _result(
            client, auth_headers, _json(start)['data']['session']['id'],
            correct_answers=correct, score=score,
        )
        assert result.status_code == 201

    complete('memory_match', 4, 90)
    first = _json(client.get('/api/caregiver/dashboard/1', headers=caregiver_headers))['data']
    assert first['summary']['total_games_played'] == 1

    complete('word_recall', 3, 80)
    second = _json(client.get('/api/caregiver/dashboard/1', headers=caregiver_headers))['data']
    assert second['summary']['total_games_played'] == 2
    assert second['summary']['total_matches'] == 7
    assert second['recent_activities'][0]['game_id'] == 'word_recall'
