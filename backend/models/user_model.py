# Mindora Backend - User, Caregiver and Preference Models
import uuid
from database.db import Database

db = Database()

PUBLIC_USER_COLUMNS = 'id, uuid, name, email, preferred_language, age, emergency_contact, created_at'
PUBLIC_CAREGIVER_COLUMNS = 'id, uuid, name, email, phone, created_at'


class UserModel:
    @staticmethod
    def get_by_id(user_id: int):
        return db.query(
            f'SELECT {PUBLIC_USER_COLUMNS} FROM users WHERE id = ?',
            (user_id,),
            one=True,
        )

    @staticmethod
    def get_by_email(email: str):
        return db.query(
            'SELECT * FROM users WHERE email = ?',
            (email.lower().strip(),),
            one=True,
        )

    @staticmethod
    def create(name, email, password_hash, preferred_language='English', age=None, emergency_contact=None):
        user_uuid = f'usr_{uuid.uuid4().hex[:12]}'
        user_id = db.execute(
            """
            INSERT INTO users (uuid, name, email, password_hash, preferred_language, age, emergency_contact)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (user_uuid, name.strip(), email.lower().strip(), password_hash, preferred_language, age, emergency_contact),
        )
        PreferenceModel.ensure(user_id, preferred_language)
        games = ['memory_match', 'pattern_match', 'word_recall', 'sound_recognition']
        for game in games:
            db.execute(
                """
                INSERT INTO level_progression (user_id, game_id, unlocked_level, completed_levels, stars_map)
                VALUES (?, ?, 1, '[]', '{}')
                """,
                (user_id, game),
            )
            db.execute(
                'INSERT INTO game_progress (user_id, game_id) VALUES (?, ?)',
                (user_id, game),
            )
        return UserModel.get_by_id(user_id)

    @staticmethod
    def update_language(user_id: int, language: str):
        db.execute(
            'UPDATE users SET preferred_language = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
            (language, user_id),
        )
        db.execute(
            """
            INSERT INTO user_preferences (user_id, preferred_language)
            VALUES (?, ?)
            ON CONFLICT(user_id) DO UPDATE SET preferred_language = excluded.preferred_language,
                updated_at = CURRENT_TIMESTAMP
            """,
            (user_id, language),
        )
        return UserModel.get_by_id(user_id)


class CaregiverModel:
    @staticmethod
    def get_by_id(caregiver_id: int):
        return db.query(
            f'SELECT {PUBLIC_CAREGIVER_COLUMNS} FROM caregivers WHERE id = ?',
            (caregiver_id,),
            one=True,
        )

    @staticmethod
    def get_by_email(email: str):
        return db.query(
            'SELECT * FROM caregivers WHERE email = ?',
            (email.lower().strip(),),
            one=True,
        )

    @staticmethod
    def create(name, email, password_hash, phone=None):
        cg_uuid = f'cg_{uuid.uuid4().hex[:12]}'
        caregiver_id = db.execute(
            """
            INSERT INTO caregivers (uuid, name, email, password_hash, phone)
            VALUES (?, ?, ?, ?, ?)
            """,
            (cg_uuid, name.strip(), email.lower().strip(), password_hash, phone),
        )
        return CaregiverModel.get_by_id(caregiver_id)


class PreferenceModel:
    @staticmethod
    def ensure(user_id, preferred_language='English'):
        existing = PreferenceModel.get(user_id)
        if existing:
            return existing
        db.execute(
            """
            INSERT INTO user_preferences (user_id, preferred_language, share_mood_with_caregiver)
            VALUES (?, ?, 0)
            """,
            (user_id, preferred_language),
        )
        return PreferenceModel.get(user_id)

    @staticmethod
    def get(user_id):
        return db.query(
            'SELECT * FROM user_preferences WHERE user_id = ?',
            (user_id,),
            one=True,
        )

    @staticmethod
    def update(user_id, **fields):
        PreferenceModel.ensure(user_id)
        allowed = {
            'preferred_language',
            'share_mood_with_caregiver',
            'text_size',
            'background_music',
            'music_volume',
        }
        updates = []
        values = []
        for key, value in fields.items():
            if key in allowed and value is not None:
                updates.append(f'{key} = ?')
                values.append(value)
        if not updates:
            return PreferenceModel.get(user_id)
        values.append(user_id)
        db.execute(
            f"UPDATE user_preferences SET {', '.join(updates)}, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?",
            tuple(values),
        )
        prefs = PreferenceModel.get(user_id)
        if 'preferred_language' in fields and fields['preferred_language']:
            db.execute(
                'UPDATE users SET preferred_language = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                (fields['preferred_language'], user_id),
            )
        return prefs

    @staticmethod
    def shares_mood(user_id):
        prefs = PreferenceModel.get(user_id)
        return bool(prefs and prefs.get('share_mood_with_caregiver'))
