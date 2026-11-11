# Mindora - Flask REST API Backend
import logging
import os
import sqlite3
from flask import Flask, jsonify
from flask_cors import CORS
from config import get_config, config_by_name
from database.db import init_db, set_active_db_path, get_db_connection
from routes import auth_bp, game_bp, mood_bp, caregiver_bp, ml_bp
from utils.response import error_response, success_response


def create_app(config_name=None, database_path=None):
    app = Flask(__name__)

    if config_name and config_name in config_by_name:
        os.environ['FLASK_ENV'] = config_name
        app.config.from_object(config_by_name[config_name])
    else:
        app.config.from_object(get_config())

    if config_name == 'production':
        config_by_name['production'].validate_for_production()

    if database_path:
        app.config['DATABASE_PATH'] = database_path

    logging.basicConfig(
        level=logging.DEBUG if app.config.get('DEBUG') else logging.INFO,
        format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    )

    origins = app.config.get('CORS_ORIGINS') or ['*']
    CORS(
        app,
        resources={r'/api/*': {'origins': origins}},
        allow_headers=['Content-Type', 'Authorization'],
        methods=['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
        max_age=600,
    )

    db_path = app.config.get('DATABASE_PATH')
    set_active_db_path(db_path)
    try:
        init_db(db_path)
        # Server-side diagnostic only: confirms which SQLite file receives writes.
        app.logger.info('Mindora database file: %s', os.path.abspath(str(db_path)))
    except Exception as exc:
        app.logger.error('Database initialization failed: %s', exc)
        if app.config.get('TESTING'):
            raise

    app.register_blueprint(auth_bp)
    app.register_blueprint(game_bp)
    app.register_blueprint(mood_bp)
    app.register_blueprint(caregiver_bp)
    app.register_blueprint(ml_bp)

    @app.route('/api/health', methods=['GET'])
    def health_check():
        database_ok = True
        try:
            conn = get_db_connection()
            conn.execute('SELECT 1')
            conn.close()
        except Exception as exc:
            database_ok = False
            app.logger.error('Health check database failure: %s', exc)
        payload = {
            'status': 'healthy' if database_ok else 'degraded',
            'service': 'Mindora Cognitive Wellness Backend',
            'version': '1.0.0',
            'problem_statement': 'SIH26003',
            'database': 'SQLite connected' if database_ok else 'SQLite unavailable',
            'database_file': os.path.basename(str(db_path)) if db_path else None,
            'adaptive_engine': 'rule_based',
            'ml_trained': False,
            'games_supported': [
                'memory_match',
                'pattern_match',
                'word_recall',
                'sound_recognition',
            ],
        }
        return success_response(
            data=payload,
            message='Mindora API is running.' if database_ok else 'Mindora API is degraded.',
            status_code=200 if database_ok else 503,
        )

    @app.route('/', methods=['GET'])
    def index():
        return jsonify({
            'name': 'Mindora API',
            'title': 'AI-Assisted Cognitive Gaming and Memory Support Platform for Dementia Care',
            'health_check': '/api/health',
        })

    @app.errorhandler(400)
    def bad_request(e):
        return error_response(str(getattr(e, 'description', 'Bad request.')), status_code=400)

    @app.errorhandler(401)
    def unauthorized(e):
        return error_response(str(getattr(e, 'description', 'Authentication required.')), status_code=401)

    @app.errorhandler(403)
    def forbidden(e):
        return error_response(str(getattr(e, 'description', 'Access denied.')), status_code=403)

    @app.errorhandler(404)
    def not_found(e):
        return error_response('The requested resource was not found on this server.', status_code=404)

    @app.errorhandler(405)
    def method_not_allowed(e):
        return error_response('HTTP method not allowed for this route.', status_code=405)

    @app.errorhandler(409)
    def conflict(e):
        return error_response(str(getattr(e, 'description', 'The request conflicts with existing data.')), status_code=409)

    @app.errorhandler(413)
    def payload_too_large(e):
        return error_response('Request body is too large.', status_code=413)

    @app.errorhandler(429)
    def too_many_requests(e):
        return error_response(str(getattr(e, 'description', 'Too many requests. Please try again later.')), status_code=429)

    @app.errorhandler(sqlite3.IntegrityError)
    def integrity_error(e):
        app.logger.warning('Database constraint violation: %s', e)
        return error_response('The request could not be completed because of a data conflict.', status_code=409)

    @app.errorhandler(Exception)
    def internal_error(e):
        if isinstance(e, (SystemExit, KeyboardInterrupt)):
            raise e
        app.logger.exception('Unhandled server error')
        if app.config.get('TESTING'):
            raise e
        return error_response('An internal server error occurred. Please try again.', status_code=500)

    @app.after_request
    def security_headers(response):
        response.headers.setdefault('X-Content-Type-Options', 'nosniff')
        response.headers.setdefault('X-Frame-Options', 'DENY')
        response.headers.setdefault('Referrer-Policy', 'no-referrer')
        response.headers.setdefault('Cache-Control', 'no-store')
        if response.content_type and 'application/json' in response.content_type:
            response.headers.setdefault('Content-Type', 'application/json; charset=utf-8')
        return response

    return app


app = create_app()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    host = os.environ.get('HOST', '0.0.0.0')
    debug = os.environ.get('FLASK_DEBUG', '1') == '1'
    print(f'Mindora Backend launching on http://{host}:{port}')
    app.run(host=host, port=port, debug=debug)
