# Mindora Backend - Mood & Feel Good Wellness Routes
from flask import Blueprint, request
from models.mood_model import MoodModel, FeelGoodModel
from models.user_model import PreferenceModel
from middleware.auth_middleware import user_required
from utils.response import success_response, error_response
from utils.validators import validate_required_fields

mood_bp = Blueprint('wellness', __name__, url_prefix='/api/wellness')

MOODS = {'Happy', 'Calm', 'Okay', 'Sad', 'Worried', 'Confused', "I don't know"}
ACTIVITY_TYPES = {'breathing', 'nature', 'encouragement', 'music', 'rest', 'other'}


@mood_bp.route('/mood', methods=['POST'])
@user_required()
def log_mood():
    data = request.get_json(silent=True) or {}
    missing = validate_required_fields(data, ['mood'])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}")

    mood = str(data['mood']).strip()
    if mood not in MOODS:
        return error_response('Unsupported mood value.')

    try:
        energy_level = int(data.get('energy_level', 3))
    except (TypeError, ValueError):
        return error_response("Field 'energy_level' must be a whole number between 1 and 5.")
    if not 1 <= energy_level <= 5:
        return error_response("Field 'energy_level' must be between 1 and 5.")

    note = data.get('note')
    if note is not None:
        note = str(note).strip()[:500] or None

    record = MoodModel.create(
        user_id=request.current_user['user_id'],
        mood=mood,
        energy_level=energy_level,
        note=note,
    )
    return success_response(data={'mood_log': record}, message='Mood recorded successfully.', status_code=201)


@mood_bp.route('/mood', methods=['GET'])
@user_required()
def get_mood_history():
    limit = request.args.get('limit', default=30, type=int)
    offset = request.args.get('offset', default=0, type=int)
    limit = 30 if limit is None else max(1, min(limit, 100))
    offset = 0 if offset is None else max(0, offset)
    history = MoodModel.get_history(user_id=request.current_user['user_id'], limit=limit, offset=offset)
    return success_response(data={'history': history, 'limit': limit, 'offset': offset})


@mood_bp.route('/feel-good', methods=['POST'])
@user_required()
def log_feel_good():
    data = request.get_json(silent=True) or {}
    missing = validate_required_fields(data, ['activity_type'])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}")

    activity_type = str(data['activity_type']).strip().lower()
    if activity_type not in ACTIVITY_TYPES:
        return error_response('Unsupported activity type.')

    title = data.get('title')
    if title is not None:
        title = str(title).strip()[:120] or None

    try:
        duration_seconds = float(data.get('duration_seconds', 0.0))
    except (TypeError, ValueError):
        return error_response("Field 'duration_seconds' must be a number.")
    if not 0.0 <= duration_seconds <= 86400.0:
        return error_response("Field 'duration_seconds' must be between 0 and 86400.")

    record = FeelGoodModel.create(
        user_id=request.current_user['user_id'],
        activity_type=activity_type,
        title=title,
        duration_seconds=duration_seconds,
        completed=bool(data.get('completed', True)),
    )
    return success_response(data={'feel_good_log': record}, message='Feel good activity logged.', status_code=201)


@mood_bp.route('/feel-good', methods=['GET'])
@user_required()
def get_feel_good_history():
    limit = request.args.get('limit', default=30, type=int)
    offset = request.args.get('offset', default=0, type=int)
    limit = 30 if limit is None else max(1, min(limit, 100))
    offset = 0 if offset is None else max(0, offset)
    history = FeelGoodModel.get_history(user_id=request.current_user['user_id'], limit=limit, offset=offset)
    return success_response(data={'history': history, 'limit': limit, 'offset': offset})


@mood_bp.route('/consent', methods=['PUT'])
@user_required()
def update_mood_consent():
    data = request.get_json(silent=True) or {}
    if 'share_mood_with_caregiver' not in data:
        return error_response("Field 'share_mood_with_caregiver' is required.")
    prefs = PreferenceModel.update(
        request.current_user['user_id'],
        share_mood_with_caregiver=1 if data.get('share_mood_with_caregiver') else 0,
    )
    return success_response(
        data={'preferences': prefs},
        message='Mood sharing preference saved. Mood is only visible to caregivers when you allow it.',
    )
