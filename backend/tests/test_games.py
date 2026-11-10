import json


def test_record_game_session_with_adaptive_engine(client, auth_headers):
    payload = {
        'game_id': 'memory_match',
        'level': 1,
        'duration_seconds': 28.5,
        'moves': 8,
        'correct_matches': 4,
        'mistakes': 0,
        'hints_used': 0,
        'completed': True,
    }
    resp = client.post('/api/games/session', json=payload, headers=auth_headers)
    assert resp.status_code == 201
    data = json.loads(resp.data)
    session = data['data']['session']
    assert session['game_id'] == 'memory_match'
    assert session['moves'] == 8
    ml = data['data']['adaptive_ml']
    assert ml['band'] in ['encourage', 'steady', 'advance']
    assert ml['engine'] == 'rule_based'
    assert ml['ml_trained'] is False


def test_start_and_submit_session(client, auth_headers):
    start = client.post(
        '/api/games/sessions/start',
        json={'game_id': 'word_recall', 'level': 1},
        headers=auth_headers,
    )
    assert start.status_code == 201
    session_id = json.loads(start.data)['data']['session']['id']
    result = client.post(
        f'/api/games/sessions/{session_id}/result',
        json={
            'correct_answers': 3,
            'incorrect_answers': 1,
            'hints_used': 0,
            'duration_seconds': 40,
            'completed': True,
            'score': 80,
            'level': 1,
        },
        headers=auth_headers,
    )
    assert result.status_code == 201
    body = json.loads(result.data)['data']['session']
    assert body['status'] == 'completed'


def test_interrupted_session(client, auth_headers):
    start = client.post(
        '/api/games/sessions/start',
        json={'game_id': 'pattern_match', 'level': 2},
        headers=auth_headers,
    )
    session_id = json.loads(start.data)['data']['session']['id']
    result = client.post(
        f'/api/games/sessions/{session_id}/result',
        json={'correct_answers': 0, 'incorrect_answers': 2, 'completed': False, 'duration_seconds': 12},
        headers=auth_headers,
    )
    assert result.status_code == 201
    assert json.loads(result.data)['data']['session']['status'] == 'interrupted'


def test_get_progression(client, auth_headers):
    resp = client.get('/api/games/progression', headers=auth_headers)
    assert resp.status_code == 200
    prog = json.loads(resp.data)['data']['progression']
    assert 'memory_match' in prog
    assert 'pattern_match' in prog
    assert 'word_recall' in prog
    assert 'sound_recognition' in prog


def test_update_progression(client, auth_headers):
    payload = {
        'game_id': 'sound_recognition',
        'unlocked_level': 2,
        'completed_level': 1,
        'stars': 3,
    }
    resp = client.put('/api/games/progression', json=payload, headers=auth_headers)
    assert resp.status_code == 200
    prog = json.loads(resp.data)['data']['progression']
    assert prog['sound_recognition']['unlocked_level'] >= 2


def test_history_and_progress_require_auth(client):
    assert client.get('/api/games/sessions').status_code == 401
    assert client.get('/api/games/progress').status_code == 401


def test_progress_after_session(client, auth_headers):
    client.post(
        '/api/games/session',
        json={'game_id': 'memory_match', 'level': 1, 'correct_matches': 4, 'mistakes': 1, 'completed': True},
        headers=auth_headers,
    )
    resp = client.get('/api/games/progress', headers=auth_headers)
    assert resp.status_code == 200
    data = json.loads(resp.data)['data']
    assert data['summary']['overview']['total_games'] >= 1
