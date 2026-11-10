import json


def test_ml_predict_advance_band(client):
    payload = {
        'accuracy_ratio': 1.0,
        'duration_seconds': 18.0,
        'mistakes': 0,
        'hints_used': 0,
        'level': 1,
        'relaxed_mode': False,
    }
    resp = client.post('/api/ml/predict-difficulty', json=payload)
    assert resp.status_code == 200
    data = json.loads(resp.data)['data']
    assert data['band'] == 'advance'
    assert data['recommended_level'] == 2
    assert data['engine'] == 'rule_based'


def test_ml_predict_encourage_band(client):
    payload = {
        'accuracy_ratio': 0.25,
        'duration_seconds': 120.0,
        'mistakes': 6,
        'hints_used': 3,
        'level': 2,
        'relaxed_mode': False,
    }
    resp = client.post('/api/ml/predict-difficulty', json=payload)
    assert resp.status_code == 200
    data = json.loads(resp.data)['data']
    assert data['band'] == 'encourage'
    assert data['recommended_level'] == 2


def test_ml_model_info(client):
    resp = client.get('/api/ml/model-info')
    assert resp.status_code == 200
    data = json.loads(resp.data)['data']
    assert data['ml_trained'] is False
    assert data['engine'] == 'rule_based'


def test_mood_storage(client, auth_headers):
    resp = client.post('/api/wellness/mood', json={'mood': 'Calm', 'energy_level': 4}, headers=auth_headers)
    assert resp.status_code == 201
    history = client.get('/api/wellness/mood', headers=auth_headers)
    assert history.status_code == 200
    items = json.loads(history.data)['data']['history']
    assert items[0]['mood'] == 'Calm'


def test_feel_good_storage(client, auth_headers):
    resp = client.post(
        '/api/wellness/feel-good',
        json={'activity_type': 'breathing', 'title': 'Gentle breathing', 'duration_seconds': 48},
        headers=auth_headers,
    )
    assert resp.status_code == 201


def test_database_persistence_across_queries(client, auth_headers):
    client.post(
        '/api/games/session',
        json={'game_id': 'sound_recognition', 'level': 1, 'correct_matches': 3, 'mistakes': 0, 'completed': True},
        headers=auth_headers,
    )
    history = client.get('/api/games/sessions', headers=auth_headers)
    sessions = json.loads(history.data)['data']['sessions']
    assert any(s['game_id'] == 'sound_recognition' for s in sessions)
