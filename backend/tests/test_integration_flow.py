"""End-to-end API flow used as the integration verification for Mindora.

This exercises the same HTTP contract the Flutter client uses:
register -> login -> start game -> submit result -> progress -> pairing ->
caregiver login -> authorized dashboard -> blocked unauthorized access.
"""
import json


def _json(resp):
    return json.loads(resp.data)


def test_complete_user_and_caregiver_journey(client):
    # 1. Register a loved one.
    register = client.post('/api/auth/register', json={
        'name': 'End To End',
        'email': 'e2e-user@example.org',
        'password': 'SecurePassword123',
        'preferred_language': 'Assamese',
    })
    assert register.status_code == 201
    user_id = _json(register)['data']['user']['id']

    # 2. Log in.
    login = client.post('/api/auth/login', json={
        'email': 'e2e-user@example.org',
        'password': 'SecurePassword123',
    })
    assert login.status_code == 200
    token = _json(login)['data']['token']
    headers = {'Authorization': f'Bearer {token}'}

    # 3. Start a game.
    start = client.post('/api/games/sessions/start', json={
        'game_id': 'memory_match', 'level': 1,
    }, headers=headers)
    assert start.status_code == 201
    session_id = _json(start)['data']['session']['id']

    # 4. Complete the game and submit the result.
    result = client.post(f'/api/games/sessions/{session_id}/result', json={
        'correct_answers': 6,
        'incorrect_answers': 1,
        'hints_used': 0,
        'duration_seconds': 54,
        'completed': True,
        'score': 92,
    }, headers=headers)
    assert result.status_code == 201
    assert _json(result)['data']['session']['status'] == 'completed'

    # 5. Verify persistence and progress retrieval through the API.
    sessions = _json(client.get('/api/games/sessions', headers=headers))['data']['sessions']
    assert len(sessions) == 1
    assert sessions[0]['correct_matches'] == 6
    progress = _json(client.get('/api/games/progress', headers=headers))['data']
    assert progress['summary']['overview']['total_games'] == 1
    assert progress['progression']['memory_match']['unlocked_level'] == 2

    # 6. Generate a pairing code.
    code_resp = client.post('/api/caregiver/generate-code', headers=headers)
    assert code_resp.status_code == 200
    code = _json(code_resp)['data']['pairing_code']
    assert code.startswith('MIND-') and len(code) == 14

    # 7. Register and sign in as a caregiver.
    cg = client.post('/api/auth/register', json={
        'name': 'Family Member',
        'email': 'e2e-caregiver@example.org',
        'password': 'SecurePassword123',
        'role': 'caregiver',
    })
    assert cg.status_code == 201
    cg_login = client.post('/api/auth/caregiver/login', json={
        'email': 'e2e-caregiver@example.org',
        'password': 'SecurePassword123',
    })
    assert cg_login.status_code == 200
    cg_headers = {'Authorization': f"Bearer {_json(cg_login)['data']['token']}"}

    # 8. Pair with the loved one.
    pair = client.post('/api/caregiver/pair', json={'pairing_code': code}, headers=cg_headers)
    assert pair.status_code == 200
    assert _json(pair)['data']['paired_user']['id'] == user_id

    # 9. Authorized dashboard shows real persisted data.
    dashboard = client.get(f'/api/caregiver/dashboard/{user_id}', headers=cg_headers)
    assert dashboard.status_code == 200
    data = _json(dashboard)['data']
    assert data['user']['name'] == 'End To End'
    assert data['summary']['total_games_played'] == 1
    assert data['recent_activities'][0]['game_id'] == 'memory_match'
    assert data['mood_shared'] is False

    # 10. Mood is private until explicit consent.
    client.post('/api/wellness/mood', json={'mood': 'Calm'}, headers=headers)
    assert _json(client.get(f'/api/caregiver/dashboard/{user_id}', headers=cg_headers))['data']['mood_history'] == []
    client.put('/api/wellness/consent', json={'share_mood_with_caregiver': True}, headers=headers)
    shared = _json(client.get(f'/api/caregiver/dashboard/{user_id}', headers=cg_headers))['data']
    assert shared['mood_shared'] is True
    assert shared['mood_history'][0]['mood'] == 'Calm'

    # 11. An unrelated caregiver is blocked.
    stranger = client.post('/api/auth/register', json={
        'name': 'Unrelated Caregiver',
        'email': 'e2e-stranger@example.org',
        'password': 'SecurePassword123',
        'role': 'caregiver',
    })
    stranger_headers = {'Authorization': f"Bearer {_json(stranger)['data']['token']}"}
    blocked = client.get(f'/api/caregiver/dashboard/{user_id}', headers=stranger_headers)
    assert blocked.status_code == 403
