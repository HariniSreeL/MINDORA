# Mindora Backend - Adaptive Difficulty Routes
# Rule-based engine is active. Scikit-learn is reserved for future genuine data.
from flask import Blueprint, request
from services.adaptive_service import adaptive_engine
from middleware.auth_middleware import jwt_required, user_required
from utils.response import success_response, error_response
from utils.validators import validate_required_fields
from database.db import Database

db = Database()
ml_bp = Blueprint('ml', __name__, url_prefix='/api/ml')


@ml_bp.route('/predict-difficulty', methods=['POST'])
def predict_difficulty():
    data = request.get_json() or {}
    missing = validate_required_fields(data, ['accuracy_ratio', 'mistakes'])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}")
    result = adaptive_engine.evaluate_performance(
        accuracy_ratio=float(data.get('accuracy_ratio', 1.0)),
        duration_seconds=float(data.get('duration_seconds', 0.0)),
        mistakes=int(data.get('mistakes', 0)),
        hints_used=int(data.get('hints_used', 0)),
        level=int(data.get('level', 1)),
        relaxed_mode=bool(data.get('relaxed_mode', False)),
        completed=bool(data.get('completed', True)),
    )
    return success_response(data=result)


@ml_bp.route('/adaptive-state/<game_id>', methods=['GET'])
@user_required()
def get_adaptive_state(game_id):
    user_id = request.current_user['user_id']
    row = db.query(
        """
        SELECT * FROM adaptive_difficulty_states
        WHERE user_id = ? AND game_id = ?
        """,
        (user_id, game_id),
        one=True,
    )
    if not row:
        return success_response(data={
            'game_id': game_id,
            'current_band': 'steady',
            'recommended_level': 1,
            'engine': 'rule_based',
            'ml_trained': False,
        })
    row['engine'] = 'rule_based'
    row['ml_trained'] = False
    return success_response(data=row)


@ml_bp.route('/model-info', methods=['GET'])
def get_model_info():
    return success_response(data={
        'engine': 'rule_based',
        'ml_trained': False,
        'sklearn_status': 'reserved_for_future_training',
        'library': 'rule-based (scikit-learn interface reserved)',
        'model_type': 'HeuristicAdaptiveEngine',
        'features': ['recent_accuracy', 'repeated_mistakes', 'hints_used', 'level_completion', 'consistency'],
        'target_classes': ['encourage', 'steady', 'advance'],
        'note': 'No synthetic medical dataset was used. A scikit-learn Decision Tree can be trained later from genuine game sessions.',
    })
