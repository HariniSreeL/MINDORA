# Mindora Backend - Configuration
import os
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parent / '.env')
except ImportError:
    pass

BASE_DIR = Path(__file__).resolve().parent

_DEV_SECRET = 'mindora_dev_only_secret_change_me_2026'
_DEV_JWT_SECRET = 'mindora_dev_only_jwt_secret_change_me_2026'


def _env_bool(name, default=False):
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {'1', 'true', 'yes', 'on'}


def _cors_origins():
    raw = os.environ.get('CORS_ORIGINS', '*').strip()
    if not raw or raw == '*':
        return ['*']
    return [origin.strip() for origin in raw.split(',') if origin.strip()]


class Config:
    """Base configuration. Safe defaults are for local development only."""
    SECRET_KEY = os.environ.get('SECRET_KEY', _DEV_SECRET)
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY', _DEV_JWT_SECRET)
    JWT_EXPIRATION_HOURS = max(1, int(os.environ.get('JWT_EXPIRATION_HOURS', 72)))
    DATABASE_PATH = os.environ.get(
        'DATABASE_PATH',
        str(BASE_DIR / 'database' / 'mindora.db'),
    )
    CORS_ORIGINS = _cors_origins()
    SEED_DEMO_DATA = _env_bool('SEED_DEMO_DATA', True)
    MAX_CONTENT_LENGTH = 1024 * 1024  # 1 MiB request body limit
    JSON_SORT_KEYS = False
    LOGIN_MAX_ATTEMPTS = int(os.environ.get('LOGIN_MAX_ATTEMPTS', 8))
    LOGIN_WINDOW_SECONDS = int(os.environ.get('LOGIN_WINDOW_SECONDS', 300))
    PAIRING_CODE_TTL_MINUTES = int(os.environ.get('PAIRING_CODE_TTL_MINUTES', 15))

    @classmethod
    def validate_for_production(cls):
        """Fail fast instead of running production with development secrets."""
        problems = []
        if not cls.SECRET_KEY or cls.SECRET_KEY == _DEV_SECRET or len(cls.SECRET_KEY) < 32:
            problems.append('SECRET_KEY must be a unique value of at least 32 characters.')
        if not cls.JWT_SECRET_KEY or cls.JWT_SECRET_KEY == _DEV_JWT_SECRET or len(cls.JWT_SECRET_KEY) < 32:
            problems.append('JWT_SECRET_KEY must be a unique value of at least 32 characters.')
        if cls.CORS_ORIGINS == ['*']:
            problems.append('CORS_ORIGINS must list explicit frontend origins in production.')
        if problems:
            raise RuntimeError('Invalid production configuration: ' + ' '.join(problems))


class DevelopmentConfig(Config):
    DEBUG = _env_bool('FLASK_DEBUG', True)
    TESTING = False
    SEED_DEMO_DATA = _env_bool('SEED_DEMO_DATA', True)


class TestingConfig(Config):
    DEBUG = True
    TESTING = True
    DATABASE_PATH = os.environ.get('TEST_DATABASE_PATH', ':memory:')
    SEED_DEMO_DATA = True


class ProductionConfig(Config):
    DEBUG = False
    TESTING = False
    # No fallback values: production must supply secrets through the environment.
    SECRET_KEY = os.environ.get('SECRET_KEY')
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY')
    SEED_DEMO_DATA = False


config_by_name = {
    'development': DevelopmentConfig,
    'testing': TestingConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig,
}


def get_config():
    env = os.environ.get('FLASK_ENV', 'development').lower()
    config = config_by_name.get(env, DevelopmentConfig)
    if config is ProductionConfig:
        config.validate_for_production()
    return config
