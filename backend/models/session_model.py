# Mindora Backend - Game Sessions, Results, Progress and Levels
import json
from database.db import Database
from services.adaptive_service import GAME_NAMES

db = Database()


class SessionModel:
    @staticmethod
    def start_session(user_id, game_id, level=1, relaxed_mode=False, cognitive_domain='general'):
        game_name = GAME_NAMES.get(game_id, game_id)
        session_id = db.execute(
            """
            INSERT INTO game_sessions (
                user_id, game_id, game_name, level, completed, status, relaxed_mode, cognitive_domain
            ) VALUES (?, ?, ?, ?, 0, 'started', ?, ?)
            """,
            (user_id, game_id, game_name, level, 1 if relaxed_mode else 0, cognitive_domain),
        )
        return db.query('SELECT * FROM game_sessions WHERE id = ?', (session_id,), one=True)

    @staticmethod
    def submit_result(session_id, user_id, score, correct_answers, incorrect_answers, hints_used,
                      duration_seconds, completed, moves=0, total_attempts=0, performance_band='steady'):
        session = db.query(
            'SELECT * FROM game_sessions WHERE id = ? AND user_id = ?',
            (session_id, user_id),
            one=True,
        )
        if not session:
            return None

        status = 'completed' if completed else 'interrupted'
        attempts = total_attempts or (correct_answers + incorrect_answers)
        db.execute(
            """
            UPDATE game_sessions SET
                duration_seconds = ?, moves = ?, correct_matches = ?, mistakes = ?,
                hints_used = ?, total_attempts = ?, completed = ?, status = ?,
                score = ?, performance_band = ?, ended_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (
                duration_seconds,
                moves or attempts,
                correct_answers,
                incorrect_answers,
                hints_used,
                attempts,
                1 if completed else 0,
                status,
                score,
                performance_band,
                session_id,
            ),
        )
        db.execute(
            """
            INSERT INTO game_results (
                session_id, user_id, game_id, level, score, correct_answers,
                incorrect_answers, hints_used, duration_seconds, completion_status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(session_id) DO UPDATE SET
                score = excluded.score,
                correct_answers = excluded.correct_answers,
                incorrect_answers = excluded.incorrect_answers,
                hints_used = excluded.hints_used,
                duration_seconds = excluded.duration_seconds,
                completion_status = excluded.completion_status,
                submitted_at = CURRENT_TIMESTAMP
            """,
            (
                session_id,
                user_id,
                session['game_id'],
                session['level'],
                score,
                correct_answers,
                incorrect_answers,
                hints_used,
                duration_seconds,
                status,
            ),
        )
        GameProgressModel.record_play(
            user_id=user_id,
            game_id=session['game_id'],
            score=score,
            duration_seconds=duration_seconds,
        )
        return db.query('SELECT * FROM game_sessions WHERE id = ?', (session_id,), one=True)

    @staticmethod
    def create_completed_session(user_id, game_id, level, duration_seconds, moves=0, correct_matches=0,
                                 mistakes=0, hints_used=0, total_attempts=0, completed=True,
                                 relaxed_mode=False, cognitive_domain='general', score=0.0,
                                 performance_band='steady'):
        status = 'completed' if completed else 'interrupted'
        game_name = GAME_NAMES.get(game_id, game_id)
        attempts = total_attempts or (correct_matches + mistakes)
        session_id = db.execute(
            """
            INSERT INTO game_sessions (
                user_id, game_id, game_name, level, duration_seconds, moves, correct_matches,
                mistakes, hints_used, total_attempts, completed, status, relaxed_mode,
                cognitive_domain, score, performance_band, ended_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            """,
            (
                user_id, game_id, game_name, level, duration_seconds, moves, correct_matches,
                mistakes, hints_used, attempts, 1 if completed else 0, status,
                1 if relaxed_mode else 0, cognitive_domain, score, performance_band,
            ),
        )
        db.execute(
            """
            INSERT INTO game_results (
                session_id, user_id, game_id, level, score, correct_answers,
                incorrect_answers, hints_used, duration_seconds, completion_status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                session_id, user_id, game_id, level, score, correct_matches,
                mistakes, hints_used, duration_seconds, status,
            ),
        )
        GameProgressModel.record_play(user_id, game_id, score, duration_seconds)
        return db.query('SELECT * FROM game_sessions WHERE id = ?', (session_id,), one=True)

    @staticmethod
    def abandon_open_sessions(user_id, game_id=None):
        if game_id:
            db.execute(
                """
                UPDATE game_sessions SET status = 'abandoned', ended_at = CURRENT_TIMESTAMP
                WHERE user_id = ? AND game_id = ? AND status = 'started'
                """,
                (user_id, game_id),
            )
        else:
            db.execute(
                """
                UPDATE game_sessions SET status = 'abandoned', ended_at = CURRENT_TIMESTAMP
                WHERE user_id = ? AND status = 'started'
                """,
                (user_id,),
            )

    @staticmethod
    def get_user_session(session_id, user_id):
        return db.query(
            'SELECT * FROM game_sessions WHERE id = ? AND user_id = ?',
            (session_id, user_id),
            one=True,
        )

    @staticmethod
    def get_user_sessions(user_id, game_id=None, limit=50, offset=0):
        limit = max(1, min(int(limit), 100))
        offset = max(0, int(offset))
        if game_id:
            return db.query(
                """
                SELECT * FROM game_sessions
                WHERE user_id = ? AND game_id = ?
                ORDER BY created_at DESC LIMIT ? OFFSET ?
                """,
                (user_id, game_id, limit, offset),
            )
        return db.query(
            """
            SELECT * FROM game_sessions
            WHERE user_id = ?
            ORDER BY created_at DESC LIMIT ? OFFSET ?
            """,
            (user_id, limit, offset),
        )

    @staticmethod
    def get_user_game_summary(user_id):
        overview = db.query(
            """
            SELECT COUNT(*) as total_games,
                   COALESCE(SUM(duration_seconds), 0) as total_duration,
                   COALESCE(SUM(correct_matches), 0) as total_matches,
                   COALESCE(AVG(score), 0) as average_score
            FROM game_sessions
            WHERE user_id = ? AND status NOT IN ('abandoned', 'started')
            """,
            (user_id,),
            one=True,
        )
        breakdown = db.query(
            """
            SELECT game_id, game_name,
                   COUNT(*) as sessions_count,
                   MAX(level) as highest_level,
                   AVG(duration_seconds) as avg_duration,
                   SUM(correct_matches) as total_matches,
                   SUM(mistakes) as total_mistakes
            FROM game_sessions
            WHERE user_id = ? AND status NOT IN ('abandoned', 'started')
            GROUP BY game_id
            """,
            (user_id,),
        )
        return {'overview': overview, 'breakdown': breakdown}

    @staticmethod
    def get_statistics(user_id):
        return SessionModel.get_user_game_summary(user_id)


class GameProgressModel:
    @staticmethod
    def record_play(user_id, game_id, score, duration_seconds):
        db.execute(
            """
            INSERT INTO game_progress (user_id, game_id, games_played, total_score, best_score, total_duration_seconds, last_played_at)
            VALUES (?, ?, 1, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(user_id, game_id) DO UPDATE SET
                games_played = games_played + 1,
                total_score = total_score + excluded.total_score,
                best_score = MAX(best_score, excluded.best_score),
                total_duration_seconds = total_duration_seconds + excluded.total_duration_seconds,
                last_played_at = CURRENT_TIMESTAMP
            """,
            (user_id, game_id, score, score, duration_seconds),
        )

    @staticmethod
    def get_all(user_id):
        return db.query('SELECT * FROM game_progress WHERE user_id = ?', (user_id,))


class LevelProgressionModel:
    @staticmethod
    def get_all(user_id):
        rows = db.query('SELECT * FROM level_progression WHERE user_id = ?', (user_id,))
        res = {}
        for row in rows:
            res[row['game_id']] = {
                'unlocked_level': row['unlocked_level'],
                'completed_levels': json.loads(row['completed_levels'] or '[]'),
                'stars_map': json.loads(row['stars_map'] or '{}'),
            }
        return res

    @staticmethod
    def update_level(user_id, game_id, unlocked_level, completed_level=None, stars=None):
        existing = db.query(
            'SELECT * FROM level_progression WHERE user_id = ? AND game_id = ?',
            (user_id, game_id),
            one=True,
        )
        if not existing:
            completed_levels = [completed_level] if completed_level else []
            stars_map = {str(completed_level): stars} if completed_level and stars is not None else {}
            db.execute(
                """
                INSERT INTO level_progression (user_id, game_id, unlocked_level, completed_levels, stars_map)
                VALUES (?, ?, ?, ?, ?)
                """,
                (user_id, game_id, unlocked_level, json.dumps(completed_levels), json.dumps(stars_map)),
            )
        else:
            completed_levels = json.loads(existing['completed_levels'] or '[]')
            stars_map = json.loads(existing['stars_map'] or '{}')
            if completed_level and completed_level not in completed_levels:
                completed_levels.append(completed_level)
            if completed_level and stars is not None:
                stars_map[str(completed_level)] = max(stars, stars_map.get(str(completed_level), 0))
            new_unlocked = max(unlocked_level, existing['unlocked_level'])
            db.execute(
                """
                UPDATE level_progression
                SET unlocked_level = ?, completed_levels = ?, stars_map = ?, updated_at = CURRENT_TIMESTAMP
                WHERE user_id = ? AND game_id = ?
                """,
                (new_unlocked, json.dumps(completed_levels), json.dumps(stars_map), user_id, game_id),
            )
        return LevelProgressionModel.get_all(user_id)

