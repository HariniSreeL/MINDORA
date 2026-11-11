# Mindora Backend - Game Sessions & Level Progression Routes
from flask import Blueprint, request
from models.session_model import SessionModel, LevelProgressionModel, GameProgressModel
from services.adaptive_service import adaptive_engine, GAME_NAMES
from middleware.auth_middleware import jwt_required, user_required
from utils.response import success_response, error_response
from utils.validators import validate_required_fields

game_bp = Blueprint('games', __name__, url_prefix='/api/games')

MAX_LEVEL = 4


def _current_user_id():
    return request.current_user['user_id']


def _as_int(value, field, default=None, minimum=None, maximum=None):
    if value is None or value == '':
        if default is None:
            raise ValueError(f"Field '{field}' is required.")
        return default
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        raise ValueError(f"Field '{field}' must be a whole number.")
    if minimum is not None and parsed < minimum:
        raise ValueError(f"Field '{field}' must be at least {minimum}.")
    if maximum is not None and parsed > maximum:
        raise ValueError(f"Field '{field}' must be at most {maximum}.")
    return parsed


def _as_float(value, field, default=0.0, minimum=None, maximum=None):
    if value is None or value == '':
        return default
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        raise ValueError(f"Field '{field}' must be a number.")
    if minimum is not None and parsed < minimum:
        raise ValueError(f"Field '{field}' must be at least {minimum}.")
    if maximum is not None and parsed > maximum:
        raise ValueError(f"Field '{field}' must be at most {maximum}.")
    return parsed


def _parse_session_payload(data):
    game_id = str(data.get('game_id') or '').strip()
    if game_id not in GAME_NAMES:
        raise ValueError('Unsupported game.')
    level = _as_int(data.get('level'), 'level', default=1, minimum=1, maximum=MAX_LEVEL)
    duration_seconds = _as_float(data.get('duration_seconds'), 'duration_seconds', 0.0, 0.0, 86400.0)
    moves = _as_int(data.get('moves'), 'moves', 0, 0, 100000)
    correct = _as_int(
        data.get('correct_matches', data.get('correct_answers')),
        'correct_answers', 0, 0, 10000,
    )
    mistakes = _as_int(
        data.get('mistakes', data.get('incorrect_attempts', data.get('incorrect_answers'))),
        'incorrect_answers', 0, 0, 10000,
    )
    hints_used = _as_int(data.get('hints_used'), 'hints_used', 0, 0, 1000)
    completed = bool(data.get('completed', True))
    total_attempts = _as_int(
        data.get('total_attempts'), 'total_attempts',
        default=correct + mistakes, minimum=0, maximum=20000,
    )
    relaxed_mode = bool(data.get('relaxed_mode', False))
    score = _as_float(
        data.get('score'), 'score',
        default=100.0 if completed else 40.0, minimum=0.0, maximum=1000.0,
    )
    return {
        'game_id': game_id,
        'level': level,
        'duration_seconds': duration_seconds,
        'moves': moves,
        'correct': correct,
        'mistakes': mistakes,
        'hints_used': hints_used,
        'completed': completed,
        'total_attempts': total_attempts,
        'relaxed_mode': relaxed_mode,
        'score': score,
        'cognitive_domain': str(data.get('cognitive_domain') or 'general')[:40],
    }


def _client_session_id(data):
    """Optional idempotency key sent by the Flutter client."""
    raw = data.get('client_session_id')
    if raw is None:
        return None
    text = str(raw).strip()
    if not text:
        return None
    if len(text) > 64:
        raise ValueError("Field 'client_session_id' is too long.")
    if not all(char.isalnum() or char in '-_' for char in text):
        raise ValueError("Field 'client_session_id' contains invalid characters.")
    return text


def _accuracy(payload):
    if payload['total_attempts']:
        return min(1.0, payload['correct'] / payload['total_attempts'])
    return 1.0 if payload['completed'] else 0.0


def _stars_for(mistakes):
    return 3 if mistakes == 0 else (2 if mistakes <= 2 else 1)


@game_bp.route('/sessions/start', methods=['POST'])
@user_required()
def start_session():
    data = request.get_json(silent=True) or {}
    missing = validate_required_fields(data, ['game_id'])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}")
    user_id = _current_user_id()
    game_id = str(data['game_id']).strip()
    if game_id not in GAME_NAMES:
        return error_response('Unsupported game.')
    try:
        level = _as_int(data.get('level'), 'level', default=1, minimum=1, maximum=MAX_LEVEL)
        client_session_id = _client_session_id(data)
    except ValueError as exc:
        return error_response(str(exc))

    # Only stale sessions are abandoned; a result for the level that just
    # finished may still be in flight.
    SessionModel.abandon_open_sessions(user_id, game_id)
    session = SessionModel.start_session(
        user_id=user_id,
        game_id=game_id,
        level=level,
        relaxed_mode=bool(data.get('relaxed_mode', False)),
        cognitive_domain=str(data.get('cognitive_domain') or 'general')[:40],
        client_session_id=client_session_id,
    )
    return success_response(data={'session': session}, message='Game session started.', status_code=201)


@game_bp.route('/sessions/<int:session_id>/result', methods=['POST'])
@user_required()
def submit_session_result(session_id):
    data = request.get_json(silent=True) or {}
    user_id = _current_user_id()

    try:
        client_session_id = _client_session_id(data)
    except ValueError as exc:
        return error_response(str(exc))

    existing = SessionModel.get_user_session(session_id, user_id)
    if not existing and client_session_id:
        # The client may retry with a session id from a stale local copy. The
        # idempotency key still resolves to the right session for this user.
        existing = SessionModel.get_user_session_by_client_id(user_id, client_session_id)
    if not existing:
        return error_response('Game session not found.', status_code=404)
    if existing['status'] in ('completed', 'interrupted'):
        return success_response(
            data={'session': existing, 'duplicate': True},
            message='This game result has already been saved.',
        )

    try:
        payload = _parse_session_payload({
            **data,
            'game_id': existing['game_id'],
            'level': existing['level'],
        })
    except ValueError as exc:
        return error_response(str(exc))

    evaluation = adaptive_engine.evaluate_session(
        accuracy_ratio=_accuracy(payload),
        mistakes=payload['mistakes'],
        hints_used=payload['hints_used'],
        completed=payload['completed'],
        level=payload['level'],
    )
    session = SessionModel.submit_result(
        session_id=existing['id'],
        user_id=user_id,
        score=payload['score'],
        correct_answers=payload['correct'],
        incorrect_answers=payload['mistakes'],
        hints_used=payload['hints_used'],
        duration_seconds=payload['duration_seconds'],
        completed=payload['completed'],
        moves=payload['moves'],
        total_attempts=payload['total_attempts'],
        performance_band=evaluation['band'],
    )
    if not session:
        return error_response('Game session not found.', status_code=404)

    history_eval = adaptive_engine.evaluate_recent_history(user_id, session['game_id'], session['level'])
    adaptive_engine.persist_state(user_id, session['game_id'], history_eval)
    if payload['completed']:
        LevelProgressionModel.update_level(
            user_id=user_id,
            game_id=session['game_id'],
            unlocked_level=min(session['level'] + 1, MAX_LEVEL),
            completed_level=session['level'],
            stars=_stars_for(payload['mistakes']),
        )
    return success_response(
        data={'session': session, 'adaptive': history_eval},
        message='Game result saved.',
        status_code=201,
    )


@game_bp.route('/session', methods=['POST'])
@user_required()
def record_game_session():
    data = request.get_json(silent=True) or {}
    user_id = _current_user_id()
    try:
        payload = _parse_session_payload(data)
        client_session_id = _client_session_id(data)
    except ValueError as exc:
        return error_response(str(exc))

    evaluation = adaptive_engine.evaluate_session(
        accuracy_ratio=_accuracy(payload),
        mistakes=payload['mistakes'],
        hints_used=payload['hints_used'],
        completed=payload['completed'],
        level=payload['level'],
    )
    session = SessionModel.create_completed_session(
        user_id=user_id,
        game_id=payload['game_id'],
        level=payload['level'],
        duration_seconds=payload['duration_seconds'],
        moves=payload['moves'],
        correct_matches=payload['correct'],
        mistakes=payload['mistakes'],
        hints_used=payload['hints_used'],
        total_attempts=payload['total_attempts'],
        completed=payload['completed'],
        relaxed_mode=payload['relaxed_mode'],
        cognitive_domain=payload['cognitive_domain'],
        score=payload['score'],
        performance_band=evaluation['band'],
        client_session_id=client_session_id,
    )
    history_eval = adaptive_engine.evaluate_recent_history(user_id, payload['game_id'], payload['level'])
    adaptive_engine.persist_state(user_id, payload['game_id'], history_eval)
    if payload['completed']:
        LevelProgressionModel.update_level(
            user_id=user_id,
            game_id=payload['game_id'],
            unlocked_level=min(payload['level'] + 1, MAX_LEVEL),
            completed_level=payload['level'],
            stars=_stars_for(payload['mistakes']),
        )
    return success_response(
        data={'session': session, 'adaptive_ml': history_eval, 'adaptive': history_eval},
        message='Game session recorded.',
        status_code=201,
    )


@game_bp.route('/sessions', methods=['GET'])
@jwt_required()
def get_sessions():
    if request.current_user.get('role') == 'caregiver':
        return error_response('Use the caregiver dashboard to view paired family members.', status_code=403)
    user_id = _current_user_id()
    game_id = request.args.get('game_id')
    if game_id and game_id not in GAME_NAMES:
        return error_response('Unsupported game.')
    limit = request.args.get('limit', default=50, type=int)
    offset = request.args.get('offset', default=0, type=int)
    limit = 50 if limit is None else max(1, min(limit, 100))
    offset = 0 if offset is None else max(0, offset)
    sessions = SessionModel.get_user_sessions(user_id, game_id=game_id, limit=limit, offset=offset)
    return success_response(data={'sessions': sessions, 'limit': limit, 'offset': offset})


@game_bp.route('/history', methods=['GET'])
@user_required()
def get_history():
    return get_sessions()


@game_bp.route('/stats', methods=['GET'])
@user_required()
def get_stats():
    return success_response(data=SessionModel.get_statistics(_current_user_id()))


@game_bp.route('/summary', methods=['GET'])
@user_required()
def get_summary():
    return success_response(data=SessionModel.get_user_game_summary(_current_user_id()))


@game_bp.route('/progress', methods=['GET'])
@user_required()
def get_progress():
    user_id = _current_user_id()
    return success_response(
        data={
            'game_progress': GameProgressModel.get_all(user_id),
            'progression': LevelProgressionModel.get_all(user_id),
            'summary': SessionModel.get_user_game_summary(user_id),
        }
    )


@game_bp.route('/progression', methods=['GET'])
@user_required()
def get_progression():
    return success_response(data={'progression': LevelProgressionModel.get_all(_current_user_id())})


@game_bp.route('/progression', methods=['PUT'])
@user_required()
def update_progression():
    data = request.get_json(silent=True) or {}
    missing = validate_required_fields(data, ['game_id', 'unlocked_level'])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}")
    if data['game_id'] not in GAME_NAMES:
        return error_response('Unsupported game.')
    try:
        unlocked_level = _as_int(data['unlocked_level'], 'unlocked_level', minimum=1, maximum=MAX_LEVEL)
        completed_level = None
        if data.get('completed_level') is not None:
            completed_level = _as_int(data['completed_level'], 'completed_level', minimum=1, maximum=MAX_LEVEL)
        stars = None
        if data.get('stars') is not None:
            stars = _as_int(data['stars'], 'stars', minimum=1, maximum=3)
    except ValueError as exc:
        return error_response(str(exc))

    updated = LevelProgressionModel.update_level(
        user_id=_current_user_id(),
        game_id=data['game_id'],
        unlocked_level=unlocked_level,
        completed_level=completed_level,
        stars=stars,
    )
    return success_response(data={'progression': updated}, message='Progress saved.')
