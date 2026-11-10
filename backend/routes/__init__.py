# Mindora Backend - Routes Package
from .auth_routes import auth_bp
from .game_routes import game_bp
from .mood_routes import mood_bp
from .caregiver_routes import caregiver_bp
from .ml_routes import ml_bp

__all__ = [
    'auth_bp',
    'game_bp',
    'mood_bp',
    'caregiver_bp',
    'ml_bp'
]
