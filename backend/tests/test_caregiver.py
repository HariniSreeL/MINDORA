import json


def test_caregiver_dashboard_data(client, caregiver_headers):
    resp = client.get('/api/caregiver/dashboard', headers=caregiver_headers)
    assert resp.status_code == 200
    data = json.loads(resp.data)['data']
    assert 'user' in data
    assert 'summary' in data
    assert 'games_progress' in data
    assert 'weekly_trend' in data
    assert 'insights' in data
    raw_text = json.dumps(data)
    assert 'patient' not in raw_text.lower()


def test_caregiver_pairing_flow(client, caregiver_headers, auth_headers):
    gen_resp = client.post('/api/caregiver/generate-code', headers=auth_headers)
    assert gen_resp.status_code == 200
    code = json.loads(gen_resp.data)['data']['pairing_code']
    assert code.startswith('MIND-')

    pair_resp = client.post(
        '/api/caregiver/pair',
        json={'pairing_code': code, 'relationship': 'Daughter'},
        headers=caregiver_headers,
    )
    assert pair_resp.status_code == 200
    paired = json.loads(pair_resp.data)['data']['paired_user']
    assert paired['id'] == 1
    assert 'password_hash' not in paired


def test_unauthorized_caregiver_cannot_view_unpaired_user(client):
    register = client.post(
        '/api/auth/register',
        json={'name': 'Other CG', 'email': 'othercg@example.org', 'password': 'Secret123', 'role': 'caregiver'},
    )
    token = json.loads(register.data)['data']['token']
    headers = {'Authorization': f'Bearer {token}'}
    resp = client.get('/api/caregiver/dashboard/1', headers=headers)
    assert resp.status_code == 403


def test_mood_hidden_without_consent(client, auth_headers, caregiver_headers):
    client.post('/api/wellness/mood', json={'mood': 'Calm'}, headers=auth_headers)
    dash = client.get('/api/caregiver/dashboard/1', headers=caregiver_headers)
    data = json.loads(dash.data)['data']
    assert data['mood_shared'] is False
    assert data['mood_history'] == []


def test_mood_visible_with_consent(client, auth_headers, caregiver_headers):
    client.put('/api/auth/preferences', json={'share_mood_with_caregiver': True}, headers=auth_headers)
    client.post('/api/wellness/mood', json={'mood': 'Happy'}, headers=auth_headers)
    dash = client.get('/api/caregiver/dashboard/1', headers=caregiver_headers)
    data = json.loads(dash.data)['data']
    assert data['mood_shared'] is True
    assert data['mood_history'][0]['mood'] == 'Happy'


def test_user_cannot_access_caregiver_dashboard(client, auth_headers):
    resp = client.get('/api/caregiver/dashboard', headers=auth_headers)
    assert resp.status_code == 403
