# Mindora Backend - Caregiver Dashboard Analytics
from datetime import datetime, timedelta
from database.db import Database
from models.user_model import PreferenceModel

db = Database()


class AnalyticsService:
    @staticmethod
    def get_loved_one_dashboard(user_id: int, include_mood: bool = False) -> dict:
        user = db.query(
            'SELECT id, uuid, name, preferred_language, age FROM users WHERE id = ?',
            (user_id,),
            one=True,
        )
        if not user:
            return None

        stats = db.query(
            """
            SELECT COUNT(*) as total_games_played,
                   COALESCE(SUM(duration_seconds), 0) as total_duration_seconds,
                   COALESCE(SUM(correct_matches), 0) as total_matches,
                   COALESCE(AVG(score), 0) as average_score
            FROM game_sessions
            WHERE user_id = ? AND status NOT IN ('abandoned', 'started')
            """,
            (user_id,),
            one=True,
        )

        game_names = {
            'memory_match': 'Memory Match',
            'pattern_match': 'Pattern Match',
            'word_recall': 'Word Recall',
            'sound_recognition': 'Sound Recognition',
        }
        games_summary = []
        for gid, gtitle in game_names.items():
            gstat = db.query(
                """
                SELECT COUNT(*) as play_count,
                       MAX(level) as highest_level,
                       COALESCE(AVG(duration_seconds), 0) as avg_duration,
                       COALESCE(SUM(correct_matches), 0) as matches,
                       COALESCE(SUM(mistakes), 0) as mistakes,
                       COALESCE(SUM(CASE WHEN completed = 1 THEN 1 ELSE 0 END), 0) as completed_count
                FROM game_sessions
                WHERE user_id = ? AND game_id = ? AND status NOT IN ('abandoned', 'started')
                """,
                (user_id, gid),
                one=True,
            )
            prog = db.query(
                'SELECT unlocked_level, completed_levels FROM level_progression WHERE user_id = ? AND game_id = ?',
                (user_id, gid),
                one=True,
            )
            games_summary.append({
                'game_id': gid,
                'title': gtitle,
                'play_count': gstat['play_count'] if gstat else 0,
                'completed_levels': prog['unlocked_level'] if prog else 1,
                'highest_level': (prog['unlocked_level'] if prog else (gstat['highest_level'] or 1)),
                'avg_duration_seconds': round(gstat['avg_duration'] if gstat else 0.0, 1),
                'total_matches': gstat['matches'] if gstat else 0,
                'total_mistakes': gstat['mistakes'] if gstat else 0,
            })

        today = datetime.now().date()
        weekly_trend = []
        for i in range(6, -1, -1):
            day = today - timedelta(days=i)
            day_str = day.strftime('%Y-%m-%d')
            day_stat = db.query(
                """
                SELECT COUNT(*) as session_count,
                       COALESCE(SUM(duration_seconds), 0) as total_seconds
                FROM game_sessions
                WHERE user_id = ? AND DATE(created_at) = ? AND status NOT IN ('abandoned', 'started')
                """,
                (user_id, day_str),
                one=True,
            )
            weekly_trend.append({
                'date': day_str,
                'day_name': day.strftime('%a'),
                'sessions': day_stat['session_count'] if day_stat else 0,
                'duration_minutes': round((day_stat['total_seconds'] if day_stat else 0) / 60.0, 1),
            })

        recent_sessions = db.query(
            """
            SELECT game_name, game_id, level, duration_seconds, score, status, created_at
            FROM game_sessions
            WHERE user_id = ? AND status NOT IN ('abandoned', 'started')
            ORDER BY created_at DESC LIMIT 8
            """,
            (user_id,),
        )

        feel_good = db.query(
            """
            SELECT activity_type, title, duration_seconds, created_at
            FROM feel_good_activities
            WHERE user_id = ?
            ORDER BY created_at DESC LIMIT 5
            """,
            (user_id,),
        )

        mood_history = []
        mood_shared = False
        if include_mood and PreferenceModel.shares_mood(user_id):
            mood_shared = True
            mood_history = db.query(
                """
                SELECT mood, energy_level, created_at
                FROM mood_logs
                WHERE user_id = ?
                ORDER BY created_at DESC LIMIT 7
                """,
                (user_id,),
            )

        insights = []
        if stats['total_games_played'] > 0:
            insights.append('Regular game play is being recorded for this family member.')
            insights.append('Session times are shown as they happened, without comparing speed.')
        else:
            insights.append('This account is ready for gentle daily games.')

        return {
            'user': user,
            'summary': {
                'total_games_played': stats['total_games_played'],
                'total_duration_minutes': round(stats['total_duration_seconds'] / 60.0, 1),
                'total_matches': stats['total_matches'],
                'average_score': round(stats['average_score'], 1),
            },
            'games_progress': games_summary,
            'weekly_trend': weekly_trend,
            'recent_activities': recent_sessions,
            'mood_shared': mood_shared,
            'mood_history': mood_history,
            'feel_good_activities': feel_good,
            'insights': insights,
        }

