# Mindora Backend - Authentication Routes
from flask import Blueprint, request
from models.user_model import UserModel, CaregiverModel, PreferenceModel
from services.auth_service import (
    hash_password,
    verify_password,
    create_access_token,
    revoke_token,
)
from middleware.auth_middleware import jwt_required, user_required
from middleware.rate_limit import is_login_blocked, record_failed_login, clear_login_attempts
from utils.response import success_response, error_response
from utils.validators import validate_email, validate_password, validate_required_fields

auth_bp = Blueprint('auth', __name__, url_prefix='/api/auth')

SUPPORTED_LANGUAGES = {
    'English', 'Hindi', 'Assamese', 'Bengali', 'Nepali',
    'Manipuri (Meitei)', 'Khasi', 'Mizo', 'Nyishi',
}
TEXT_SIZES = {'Small', 'Medium', 'Large'}
VALID_ROLES = {'user', 'caregiver'}


def _public_user(user):
    if not user:
        return None
    return {k: user[k] for k in user if k != 'password_hash'}


def _client_key(email):
    return f"{request.remote_addr}|{email or ''}"


def _too_many(retry_after):
    resp = error_response(
        'Too many sign-in attempts. Please wait a few minutes and try again.',
        status_code=429,
    )
    resp[0].headers['Retry-After'] = str(retry_after)
    return resp


@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json(silent=True) or {}
    role = str(data.get('role', 'user')).lower()

    missing = validate_required_fields(data, ['name', 'email', 'password'])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}")
    if role not in VALID_ROLES:
        return error_response("Field 'role' must be 'user' or 'caregiver'.")

    name = str(data['name']).strip()
    if not 2 <= len(name) <= 80:
        return error_response('Name must be between 2 and 80 characters.')

    email = str(data['email']).strip().lower()
    if len(email) > 254 or not validate_email(email):
        return error_response('Invalid email format.')

    password = data['password'] if isinstance(data['password'], str) else ''
    if not validate_password(password, min_length=8):
        return error_response('Password must be at least 8 characters.')

    preferred_language = str(data.get('preferred_language') or 'English')
    if preferred_language not in SUPPORTED_LANGUAGES:
        preferred_language = 'English'

    pw_hash = hash_password(password)

    if role == 'caregiver':
        if CaregiverModel.get_by_email(email):
            return error_response('A caregiver with this email already exists.', status_code=409)
        caregiver = CaregiverModel.create(
            name=name,
            email=email,
            password_hash=pw_hash,
            phone=str(data.get('phone') or '').strip()[:30] or None,
        )
        token = create_access_token(caregiver['id'], role='caregiver', email=caregiver['email'])
        return success_response(
            data={'user': caregiver, 'token': token, 'role': 'caregiver'},
            message='Caregiver registered successfully.',
            status_code=201,
        )

    if UserModel.get_by_email(email) or CaregiverModel.get_by_email(email):
        return error_response('An account with this email already exists.', status_code=409)

    age = data.get('age')
    if age is not None:
        try:
            age = int(age)
        except (TypeError, ValueError):
            return error_response('Age must be a whole number.')
        if not 1 <= age <= 120:
            return error_response('Age must be between 1 and 120.')

    user = UserModel.create(
        name=name,
        email=email,
        password_hash=pw_hash,
        preferred_language=preferred_language,
        age=age,
        emergency_contact=str(data.get('emergency_contact') or '').strip()[:40] or None,
    )
    token = create_access_token(user['id'], role='user', email=user['email'])
    return success_response(
        data={'user': user, 'token': token, 'role': 'user'},
        message='Account registered successfully.',
        status_code=201,
    )


@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json(silent=True) or {}
    missing = validate_required_fields(data, ['email', 'password'])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}")

    email = str(data['email']).strip().lower()
    password = data['password'] if isinstance(data['password'], str) else ''
    role = str(data.get('role', 'user')).lower()
    if role not in VALID_ROLES:
        role = 'user'

    key = _client_key(email)
    blocked, retry_after = is_login_blocked(key)
    if blocked:
        return _too_many(retry_after)

    if role == 'caregiver':
        cg = CaregiverModel.get_by_email(email)
        if not cg or not verify_password(password, cg['password_hash']):
            record_failed_login(key)
            return error_response('Invalid email or password.', status_code=401)
        clear_login_attempts(key)
        token = create_access_token(cg['id'], role='caregiver', email=cg['email'])
        return success_response(
            data={
                'user': _public_user(cg),
                'token': token,
                'role': 'caregiver',
            },
            message='Signed in successfully.',
        )

    user = UserModel.get_by_email(email)
    if not user or not verify_password(password, user['password_hash']):
        record_failed_login(key)
        return error_response('Invalid email or password.', status_code=401)
    clear_login_attempts(key)
    token = create_access_token(user['id'], role='user', email=user['email'])
    return success_response(
        data={
            'user': {
                'id': user['id'],
                'uuid': user['uuid'],
                'name': user['name'],
                'email': user['email'],
                'preferred_language': user['preferred_language'],
            },
            'token': token,
            'role': 'user',
        },
        message='Signed in successfully.',
    )


@auth_bp.route('/caregiver/login', methods=['POST'])
def caregiver_login():
    data = request.get_json(silent=True) or {}
    missing = validate_required_fields(data, ['email', 'password'])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}")

    email = str(data['email']).strip().lower()
    password = data['password'] if isinstance(data['password'], str) else ''

    key = _client_key(email)
    blocked, retry_after = is_login_blocked(key)
    if blocked:
        return _too_many(retry_after)

    cg = CaregiverModel.get_by_email(email)
    if not cg or not verify_password(password, cg['password_hash']):
        record_failed_login(key)
        return error_response('Invalid caregiver credentials.', status_code=401)

    clear_login_attempts(key)
    token = create_access_token(cg['id'], role='caregiver', email=cg['email'])
    return success_response(
        data={
            'caregiver': {
                'id': cg['id'],
                'uuid': cg['uuid'],
                'name': cg['name'],
                'email': cg['email'],
            },
            'token': token,
            'role': 'caregiver',
        },
        message='Caregiver authenticated successfully.',
    )


@auth_bp.route('/logout', methods=['POST'])
@jwt_required()
def logout():
    revoke_token(request.current_user)
    return success_response(message='Signed out successfully.')


@auth_bp.route('/me', methods=['GET'])
@jwt_required()
def get_current_profile():
    current = request.current_user
    user_id = current['user_id']
    role = current.get('role', 'user')
    if role == 'caregiver':
        profile = CaregiverModel.get_by_id(user_id)
    else:
        profile = UserModel.get_by_id(user_id)
    if not profile:
        return error_response('Profile not found.', status_code=404)
    return success_response(data={'profile': profile, 'role': role})


@auth_bp.route('/language', methods=['PUT'])
@user_required()
def update_language():
    data = request.get_json(silent=True) or {}
    lang = str(data.get('language') or '').strip()
    if not lang:
        return error_response("Field 'language' is required.")
    if lang not in SUPPORTED_LANGUAGES:
        return error_response('Unsupported language.')
    user_id = request.current_user['user_id']
    updated = UserModel.update_language(user_id, lang)
    return success_response(data={'user': updated}, message='Language updated successfully.')


@auth_bp.route('/preferences', methods=['GET'])
@user_required()
def get_preferences():
    prefs = PreferenceModel.ensure(request.current_user['user_id'])
    return success_response(data={'preferences': prefs})


@auth_bp.route('/preferences', methods=['PUT'])
@user_required()
def update_preferences():
    data = request.get_json(silent=True) or {}

    share_mood = data.get('share_mood_with_caregiver')
    if share_mood is not None:
        share_mood = 1 if bool(share_mood) else 0

    language = data.get('preferred_language') or data.get('language')
    if language is not None:
        language = str(language).strip()
        if language not in SUPPORTED_LANGUAGES:
            return error_response('Unsupported language.')

    text_size = data.get('text_size')
    if text_size is not None and text_size not in TEXT_SIZES:
        return error_response("Field 'text_size' must be Small, Medium or Large.")

    music_volume = data.get('music_volume')
    if music_volume is not None:
        try:
            music_volume = float(music_volume)
        except (TypeError, ValueError):
            return error_response("Field 'music_volume' must be a number between 0 and 1.")
        if not 0.0 <= music_volume <= 1.0:
            return error_response("Field 'music_volume' must be between 0 and 1.")

    background_music = data.get('background_music')
    if background_music is not None:
        background_music = 1 if bool(background_music) else 0

    prefs = PreferenceModel.update(
        request.current_user['user_id'],
        preferred_language=language,
        share_mood_with_caregiver=share_mood,
        text_size=text_size,
        background_music=background_music,
        music_volume=music_volume,
    )
    return success_response(data={'preferences': prefs}, message='Preferences saved.')
