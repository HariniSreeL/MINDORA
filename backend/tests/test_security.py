import json
import sqlite3
from datetime import datetime, timedelta, timezone


def _register(client, email, role='user', password='SecurePassword123'):
    resp = client.post('/api/auth/register', json={
        'name': 'Test Person',
        'email': email,
        'password': password,
        'role': role,
    })
    assert resp.status_code == 201, resp.data
    return json.loads(resp.data)['data']


def test_invalid_bearer_token_rejected(client):
    resp = client.get('/api/auth/me', headers={'Authorization': 'Bearer not-a-real-token'})
    assert resp.status_code == 401


def test_pairing_code_is_single_use(client, auth_headers):
    code = json.loads(client.post('/api/caregiver/generate-code', headers=auth_headers).data)['data']['pairing_code']
    first = _register(client, 'cg-one@example.org', role='caregiver')
    second = _register(client, 'cg-two@example.org', role='caregiver')
    first_headers = {'Authorization': f"Bearer {first['token']}"}
    second_headers = {'Authorization': f"Bearer {second['token']}"}

    assert client.post('/api/caregiver/pair', json={'pairing_code': code}, headers=first_headers).status_code == 200
    assert client.post('/api/caregiver/pair', json={'pairing_code': code}, headers=second_headers).status_code == 400


def test_expired_pairing_code_rejected(client, app, auth_headers):
    code = json.loads(client.post('/api/caregiver/generate-code', headers=auth_headers).data)['data']['pairing_code']
    past = (datetime.now(timezone.utc) - timedelta(minutes=30)).isoformat()
    conn = sqlite3.connect(app.config['DATABASE_PATH'])
    conn.execute('UPDATE pairing_invites SET expires_at = ? WHERE pairing_code = ?', (past, code))
    conn.commit()
    conn.close()

    cg = _register(client, 'expired-cg@example.org', role='caregiver')
    headers = {'Authorization': f"Bearer {cg['token']}"}
    assert client.post('/api/caregiver/pair', json={'pairing_code': code}, headers=headers).status_code == 400


def test_caregiver_can_unlink_loved_one(client, auth_headers, caregiver_headers):
    assert client.get('/api/caregiver/dashboard/1', headers=caregiver_headers).status_code == 200
    removed = client.delete('/api/caregiver/pair/1', headers=caregiver_headers)
    assert removed.status_code == 200
    assert client.get('/api/caregiver/dashboard/1', headers=caregiver_headers).status_code == 403
    loved = json.loads(client.get('/api/caregiver/loved-ones', headers=caregiver_headers).data)
    assert loved['data']['loved_ones'] == []


def test_user_can_withdraw_all_caregiver_access(client, auth_headers, caregiver_headers):
    resp = client.delete('/api/caregiver/pairings', headers=auth_headers)
    assert resp.status_code == 200
    assert json.loads(resp.data)['data']['revoked'] >= 1
    assert client.get('/api/caregiver/dashboard/1', headers=caregiver_headers).status_code == 403


def test_invalid_game_level_rejected(client, auth_headers):
    resp = client.post('/api/games/session', json={'game_id': 'memory_match', 'level': 9}, headers=auth_headers)
    assert resp.status_code == 400


def test_invalid_game_id_rejected(client, auth_headers):
    resp = client.post('/api/games/session', json={'game_id': 'jigsaw', 'level': 1}, headers=auth_headers)
    assert resp.status_code == 400


def test_invalid_numeric_payload_rejected(client, auth_headers):
    resp = client.post(
        '/api/games/session',
        json={'game_id': 'memory_match', 'level': 1, 'duration_seconds': 'forever'},
        headers=auth_headers,
    )
    assert resp.status_code == 400


def test_duplicate_session_submission_is_idempotent(client, auth_headers):
    start = client.post('/api/games/sessions/start', json={'game_id': 'memory_match', 'level': 1}, headers=auth_headers)
    session_id = json.loads(start.data)['data']['session']['id']
    payload = {'correct_answers': 4, 'incorrect_answers': 0, 'completed': True, 'duration_seconds': 20}
    first = client.post(f'/api/games/sessions/{session_id}/result', json=payload, headers=auth_headers)
    second = client.post(f'/api/games/sessions/{session_id}/result', json=payload, headers=auth_headers)
    assert first.status_code == 201
    assert second.status_code == 200
    assert json.loads(second.data)['data'].get('duplicate') is True


def test_submitting_another_users_session_is_blocked(client, auth_headers):
    start = client.post('/api/games/sessions/start', json={'game_id': 'word_recall', 'level': 1}, headers=auth_headers)
    session_id = json.loads(start.data)['data']['session']['id']
    other = _register(client, 'other-user@example.org')
    headers = {'Authorization': f"Bearer {other['token']}"}
    resp = client.post(
        f'/api/games/sessions/{session_id}/result',
        json={'correct_answers': 1, 'completed': True},
        headers=headers,
    )
    assert resp.status_code == 404


def test_unsupported_mood_rejected(client, auth_headers):
    resp = client.post('/api/wellness/mood', json={'mood': 'Furious'}, headers=auth_headers)
    assert resp.status_code == 400


def test_mood_history_is_paginated(client, auth_headers):
    for _ in range(3):
        client.post('/api/wellness/mood', json={'mood': 'Calm'}, headers=auth_headers)
    resp = client.get('/api/wellness/mood?limit=2&offset=0', headers=auth_headers)
    body = json.loads(resp.data)['data']
    assert len(body['history']) == 2
    assert body['limit'] == 2


def test_history_limit_is_capped(client, auth_headers):
    resp = client.get('/api/games/sessions?limit=100000', headers=auth_headers)
    assert resp.status_code == 200
    assert json.loads(resp.data)['data']['limit'] == 100


def test_registration_and_login_never_return_password_hash(client):
    reg = client.post('/api/auth/register', json={
        'name': 'Privacy Check',
        'email': 'privacy@example.org',
        'password': 'SecurePassword123',
    })
    login = client.post('/api/auth/login', json={
        'email': 'privacy@example.org',
        'password': 'SecurePassword123',
    })
    for resp in (reg, login):
        assert resp.status_code in (200, 201)
        assert 'password_hash' not in resp.get_data(as_text=True)


def test_caregiver_endpoints_require_authentication(client):
    assert client.get('/api/caregiver/dashboard').status_code == 401
    assert client.get('/api/caregiver/loved-ones').status_code == 401
    assert client.post('/api/caregiver/generate-code').status_code == 401
