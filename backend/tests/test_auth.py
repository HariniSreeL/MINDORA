import json


def test_health_check(client):
    resp = client.get('/api/health')
    assert resp.status_code == 200
    data = json.loads(resp.data)
    assert data['status'] == 'success'
    assert data['data']['status'] == 'healthy'
    assert data['data']['ml_trained'] is False


def test_user_login_success(client):
    payload = {'email': 'user@mindora.org', 'password': 'MindoraUser2026', 'role': 'user'}
    resp = client.post('/api/auth/login', json=payload)
    assert resp.status_code == 200
    data = json.loads(resp.data)
    assert data['data']['token']
    assert data['data']['user']['email'] == 'user@mindora.org'
    assert 'password_hash' not in data['data']['user']


def test_caregiver_login_success(client):
    payload = {'email': 'caregiver@mindora.org', 'password': 'MindoraCare2026'}
    resp = client.post('/api/auth/caregiver/login', json=payload)
    assert resp.status_code == 200
    data = json.loads(resp.data)
    assert data['data']['role'] == 'caregiver'
    assert 'token' in data['data']


def test_user_registration(client):
    payload = {
        'name': 'Biren Das',
        'email': 'biren@example.org',
        'password': 'SecurePassword123',
        'preferred_language': 'Assamese',
        'age': 75,
    }
    resp = client.post('/api/auth/register', json=payload)
    assert resp.status_code == 201
    data = json.loads(resp.data)
    assert data['data']['user']['name'] == 'Biren Das'
    assert 'password_hash' not in json.dumps(data['data']['user'])


def test_duplicate_registration(client):
    payload = {
        'name': 'Harini Sree',
        'email': 'user@mindora.org',
        'password': 'AnotherPass123',
    }
    resp = client.post('/api/auth/register', json=payload)
    assert resp.status_code == 409


def test_invalid_login_credentials(client):
    payload = {'email': 'user@mindora.org', 'password': 'WrongPassword!', 'role': 'user'}
    resp = client.post('/api/auth/login', json=payload)
    assert resp.status_code == 401


def test_protected_endpoint_requires_token(client):
    resp = client.get('/api/auth/me')
    assert resp.status_code == 401


def test_logout_invalidates_token(client, auth_headers):
    me = client.get('/api/auth/me', headers=auth_headers)
    assert me.status_code == 200
    out = client.post('/api/auth/logout', headers=auth_headers)
    assert out.status_code == 200
    me_again = client.get('/api/auth/me', headers=auth_headers)
    assert me_again.status_code == 401


def test_user_preferences(client, auth_headers):
    resp = client.put(
        '/api/auth/preferences',
        json={'share_mood_with_caregiver': True, 'text_size': 'Large'},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    prefs = json.loads(resp.data)['data']['preferences']
    assert prefs['share_mood_with_caregiver'] == 1
    assert prefs['text_size'] == 'Large'


def test_invalid_email_rejected(client):
    resp = client.post(
        '/api/auth/register',
        json={'name': 'A', 'email': 'not-an-email', 'password': 'abcdef'},
    )
    assert resp.status_code == 400
