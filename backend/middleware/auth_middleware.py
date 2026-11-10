# Mindora Backend - JWT Authentication Middleware
from functools import wraps
from flask import request
from services.auth_service import decode_access_token
from utils.response import error_response


def jwt_required(optional: bool = False, roles=None):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            auth_header = request.headers.get('Authorization', '')
            token = None
            if auth_header.startswith('Bearer '):
                token = auth_header.split(' ', 1)[1].strip()

            if not token:
                if optional:
                    request.current_user = None
                    return f(*args, **kwargs)
                return error_response('Authentication token is required.', status_code=401)

            try:
                decoded = decode_access_token(token)
                request.current_user = decoded
            except ValueError as exc:
                return error_response(str(exc), status_code=401)
            except Exception:
                return error_response('Authentication failed.', status_code=401)

            if roles and decoded.get('role') not in roles:
                return error_response('Access denied for this account type.', status_code=403)
            return f(*args, **kwargs)
        return decorated_function
    return decorator


def caregiver_required():
    def decorator(f):
        @wraps(f)
        @jwt_required(optional=False, roles=['caregiver'])
        def decorated_function(*args, **kwargs):
            return f(*args, **kwargs)
        return decorated_function
    return decorator


def user_required():
    def decorator(f):
        @wraps(f)
        @jwt_required(optional=False, roles=['user'])
        def decorated_function(*args, **kwargs):
            return f(*args, **kwargs)
        return decorated_function
    return decorator
