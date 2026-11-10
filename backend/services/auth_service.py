# Mindora Backend - Authentication & Token Service
import uuid
from datetime import datetime, timedelta, timezone
import jwt
from werkzeug.security import generate_password_hash, check_password_hash
from config import get_config
from database.db import Database

db = Database()


def hash_password(password: str) -> str:
    return generate_password_hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    if not password or not password_hash:
        return False
    return check_password_hash(password_hash, password)


def create_access_token(user_id: int, role: str = 'user', email: str = '', extra_claims: dict = None) -> str:
    config = get_config()
    now = datetime.now(timezone.utc)
    expiration = now + timedelta(hours=config.JWT_EXPIRATION_HOURS)
    payload = {
        'sub': str(user_id),
        'user_id': user_id,
        'role': role,
        'email': email,
        'jti': str(uuid.uuid4()),
        'iat': now,
        'exp': expiration,
    }
    if extra_claims:
        payload.update(extra_claims)
    return jwt.encode(payload, config.JWT_SECRET_KEY, algorithm='HS256')


def decode_access_token(token: str) -> dict:
    config = get_config()
    try:
        decoded = jwt.decode(token, config.JWT_SECRET_KEY, algorithms=['HS256'])
    except jwt.ExpiredSignatureError as exc:
        raise ValueError('Token has expired. Please sign in again.') from exc
    except jwt.InvalidTokenError as exc:
        raise ValueError('Invalid authentication token.') from exc

    jti = decoded.get('jti')
    if jti and is_token_revoked(jti):
        raise ValueError('This session has been signed out. Please sign in again.')
    return decoded


def revoke_token(decoded: dict) -> None:
    jti = decoded.get('jti')
    if not jti:
        return
    exp = decoded.get('exp')
    if isinstance(exp, (int, float)):
        expires_at = datetime.fromtimestamp(exp, tz=timezone.utc).isoformat()
    else:
        expires_at = datetime.now(timezone.utc).isoformat()
    db.execute(
        """
        INSERT OR REPLACE INTO revoked_tokens (jti, user_id, expires_at)
        VALUES (?, ?, ?)
        """,
        (jti, decoded.get('user_id'), expires_at),
    )


def is_token_revoked(jti: str) -> bool:
    row = db.query('SELECT jti FROM revoked_tokens WHERE jti = ?', (jti,), one=True)
    return row is not None
