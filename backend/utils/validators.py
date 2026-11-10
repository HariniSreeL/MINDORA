# Mindora Backend - Input Validators
import re

EMAIL_REGEX = re.compile(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$')

def validate_email(email):
    """Validates email format."""
    if not email or not isinstance(email, str):
        return False
    return bool(EMAIL_REGEX.match(email.strip()))

def validate_password(password, min_length=6):
    """Validates password length and basic complexity."""
    if not password or not isinstance(password, str):
        return False
    return len(password.strip()) >= min_length

def validate_required_fields(data, required_fields):
    """Checks for required fields in payload dictionary."""
    if not isinstance(data, dict):
        return ["Payload must be a JSON object"]
    missing = []
    for field in required_fields:
        val = data.get(field)
        if val is None or (isinstance(val, str) and not val.strip()):
            missing.append(field)
    return missing
