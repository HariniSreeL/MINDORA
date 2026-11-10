# Mindora Backend - Pytest fixtures using an isolated temporary SQLite file.
import os
import sys
import tempfile
import pytest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from services.auth_service import create_access_token


@pytest.fixture
def app():
    fd, db_path = tempfile.mkstemp(suffix='.sqlite')
    os.close(fd)
    os.environ['FLASK_ENV'] = 'testing'
    os.environ['TEST_DATABASE_PATH'] = db_path
    test_app = create_app('testing', database_path=db_path)
    yield test_app
    try:
        os.remove(db_path)
    except OSError:
        pass


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def user_token(app):
    with app.app_context():
        return create_access_token(user_id=1, role='user', email='user@mindora.org')


@pytest.fixture
def caregiver_token(app):
    with app.app_context():
        return create_access_token(user_id=1, role='caregiver', email='caregiver@mindora.org')


@pytest.fixture
def auth_headers(user_token):
    return {'Authorization': f'Bearer {user_token}'}


@pytest.fixture
def caregiver_headers(caregiver_token):
    return {'Authorization': f'Bearer {caregiver_token}'}
