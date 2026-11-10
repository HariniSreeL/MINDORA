# Mindora Backend - Standardized JSON Response Utilities
from flask import jsonify

def success_response(data=None, message="Success", status_code=200, **kwargs):
    """Formats standard success JSON response."""
    payload = {
        "status": "success",
        "message": message,
        "data": data if data is not None else {}
    }
    payload.update(kwargs)
    return jsonify(payload), status_code

def error_response(message="An error occurred", status_code=400, errors=None):
    """Formats standard error JSON response."""
    payload = {
        "status": "error",
        "message": message
    }
    if errors is not None:
        payload["errors"] = errors
    return jsonify(payload), status_code
