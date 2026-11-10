# Mindora Backend - Caregiver Portal & Pairing Routes
from flask import Blueprint, request
from models.pairing_model import PairingModel
from services.analytics_service import AnalyticsService
from middleware.auth_middleware import caregiver_required, user_required
from utils.response import success_response, error_response
from utils.validators import validate_required_fields

caregiver_bp = Blueprint('caregiver', __name__, url_prefix='/api/caregiver')


@caregiver_bp.route('/loved-ones', methods=['GET'])
@caregiver_required()
def get_paired_loved_ones():
    caregiver_id = request.current_user['user_id']
    loved_ones = PairingModel.get_paired_loved_ones(caregiver_id)
    return success_response(data={'loved_ones': loved_ones})


def _dashboard_for(caregiver_id, user_id):
    if not PairingModel.is_paired(caregiver_id, user_id):
        return None, error_response(
            'You can only view family members who are explicitly paired with you.',
            status_code=403,
        )
    dashboard_data = AnalyticsService.get_loved_one_dashboard(user_id, include_mood=True)
    if not dashboard_data:
        return None, error_response('Loved one profile not found.', status_code=404)
    return dashboard_data, None


@caregiver_bp.route('/dashboard/<int:user_id>', methods=['GET'])
@caregiver_required()
def get_dashboard_by_user(user_id):
    caregiver_id = request.current_user['user_id']
    data, err = _dashboard_for(caregiver_id, user_id)
    if err:
        return err
    return success_response(data=data)


@caregiver_bp.route('/dashboard', methods=['GET'])
@caregiver_required()
def get_default_dashboard():
    caregiver_id = request.current_user['user_id']
    loved_ones = PairingModel.get_paired_loved_ones(caregiver_id)
    if not loved_ones:
        return error_response(
            'No paired family member yet. Use a pairing code to connect.',
            status_code=404,
        )
    requested = request.args.get('user_id', type=int)
    target_id = requested or loved_ones[0]['user_id']
    data, err = _dashboard_for(caregiver_id, target_id)
    if err:
        return err
    data['loved_ones'] = [
        {'user_id': row['user_id'], 'name': row['name'], 'relationship': row.get('relationship')}
        for row in loved_ones
    ]
    return success_response(data=data)


@caregiver_bp.route('/pair', methods=['POST'])
@caregiver_required()
def pair_loved_one():
    data = request.get_json() or {}
    missing = validate_required_fields(data, ['pairing_code'])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}")
    caregiver_id = request.current_user['user_id']
    paired_user = PairingModel.pair_with_code(
        caregiver_id,
        data['pairing_code'],
        data.get('relationship', 'Family Member'),
    )
    if not paired_user:
        return error_response('Invalid, expired, or already used pairing code.', status_code=400)
    return success_response(
        data={'paired_user': paired_user},
        message=f"Successfully connected with {paired_user['name']}.",
    )


@caregiver_bp.route('/pair/<int:user_id>', methods=['DELETE'])
@caregiver_required()
def unpair_loved_one(user_id):
    caregiver_id = request.current_user['user_id']
    if not PairingModel.revoke_pairing(caregiver_id, user_id):
        return error_response('No active pairing found for this family member.', status_code=404)
    return success_response(message='Access to this family member has been removed.')


@caregiver_bp.route('/pairings', methods=['DELETE'])
@user_required()
def revoke_all_caregiver_access():
    user_id = request.current_user['user_id']
    count = PairingModel.revoke_user_pairings(user_id)
    return success_response(
        data={'revoked': count},
        message='Caregiver access has been withdrawn.',
    )


@caregiver_bp.route('/generate-code', methods=['POST'])
@user_required()
def generate_code():
    user_id = request.current_user['user_id']
    code = PairingModel.generate_pairing_code(user_id)
    from config import get_config
    return success_response(
        data={
            'pairing_code': code,
            'expires_in_minutes': max(1, get_config().PAIRING_CODE_TTL_MINUTES),
        },
        message='Pairing code generated. Share this with your family caregiver. It can be used once.',
    )
