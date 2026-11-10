# Mindora Backend - Mood & Feel Good Activity Models
from database.db import Database

db = Database()


class MoodModel:
    @staticmethod
    def create(user_id, mood, energy_level=3, note=None):
        mood_id = db.execute(
            """
            INSERT INTO mood_logs (user_id, mood, energy_level, note)
            VALUES (?, ?, ?, ?)
            """,
            (user_id, mood.strip(), energy_level, note),
        )
        return db.query('SELECT * FROM mood_logs WHERE id = ?', (mood_id,), one=True)

    @staticmethod
    def get_history(user_id, limit=30, offset=0):
        return db.query(
            """
            SELECT * FROM mood_logs
            WHERE user_id = ?
            ORDER BY created_at DESC LIMIT ? OFFSET ?
            """,
            (user_id, limit, offset),
        )


class FeelGoodModel:
    @staticmethod
    def create(user_id, activity_type, title=None, duration_seconds=0.0, completed=True):
        act_id = db.execute(
            """
            INSERT INTO feel_good_activities (user_id, activity_type, title, duration_seconds, completed)
            VALUES (?, ?, ?, ?, ?)
            """,
            (user_id, activity_type, title, duration_seconds, 1 if completed else 0),
        )
        return db.query('SELECT * FROM feel_good_activities WHERE id = ?', (act_id,), one=True)

    @staticmethod
    def get_history(user_id, limit=30, offset=0):
        return db.query(
            """
            SELECT * FROM feel_good_activities
            WHERE user_id = ?
            ORDER BY created_at DESC LIMIT ? OFFSET ?
            """,
            (user_id, limit, offset),
        )
