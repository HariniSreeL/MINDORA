# Mindora Backend - Database Management
import os
import sqlite3
from pathlib import Path
from werkzeug.security import generate_password_hash

DB_SCHEMA_PATH = Path(__file__).resolve().parent / 'schema.sql'

_active_db_path = None
_keepalive_conn = None


def set_active_db_path(db_path):
    """Sets the process-wide database path used by all model queries."""
    global _active_db_path, _keepalive_conn
    _active_db_path = db_path
    if _keepalive_conn is not None:
        try:
            _keepalive_conn.close()
        except Exception:
            pass
        _keepalive_conn = None
    if db_path and str(db_path).startswith('file:'):
        _keepalive_conn = sqlite3.connect(db_path, uri=True, check_same_thread=False)
        _keepalive_conn.execute('PRAGMA foreign_keys = ON;')


def _resolve_db_path(db_path=None):
    if db_path:
        return db_path
    if _active_db_path:
        return _active_db_path
    from config import get_config
    return get_config().DATABASE_PATH


def _is_uri(db_path):
    return str(db_path).startswith('file:')


def get_db_connection(db_path=None):
    """Establishes and returns a connection to the SQLite database."""
    db_path = _resolve_db_path(db_path)

    if db_path != ':memory:' and not _is_uri(db_path):
        os.makedirs(os.path.dirname(os.path.abspath(db_path)), exist_ok=True)

    conn = sqlite3.connect(db_path, timeout=15.0, uri=_is_uri(db_path) or db_path == ':memory:')
    conn.row_factory = sqlite3.Row
    conn.execute('PRAGMA foreign_keys = ON;')
    conn.execute('PRAGMA busy_timeout = 15000;')
    if db_path not in (':memory:',) and not _is_uri(db_path):
        try:
            conn.execute('PRAGMA journal_mode = WAL;')
        except sqlite3.DatabaseError:
            pass
    return conn


def init_db(db_path=None):
    """Initializes tables from schema.sql and optionally seeds demo records (dev/test only)."""
    from config import get_config

    resolved = _resolve_db_path(db_path)
    set_active_db_path(resolved)
    conn = get_db_connection(resolved)
    with open(DB_SCHEMA_PATH, 'r', encoding='utf-8') as f:
        schema_sql = f.read()
    with conn:
        conn.executescript(schema_sql)
        _ensure_columns(conn)
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY,
                applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        conn.execute('INSERT OR IGNORE INTO schema_migrations (version) VALUES (1)')
    if get_config().SEED_DEMO_DATA:
        _seed_initial_data(conn)
    conn.close()
    return resolved


def _ensure_columns(conn):
    """Adds columns introduced after the first schema version."""
    alterations = {
        'game_sessions': [
            ('game_name', 'TEXT'),
            ("status", "TEXT NOT NULL DEFAULT 'started'"),
            ('started_at', 'TIMESTAMP'),
            ('ended_at', 'TIMESTAMP'),
        ],
    }
    for table, columns in alterations.items():
        existing = {row[1] for row in conn.execute(f'PRAGMA table_info({table})').fetchall()}
        for name, ddl in columns:
            if name not in existing:
                conn.execute(f'ALTER TABLE {table} ADD COLUMN {name} {ddl}')


def _seed_initial_data(conn):
    """Seeds a demo loved one and caregiver if the database is empty."""
    cursor = conn.cursor()

    cursor.execute("SELECT id FROM users WHERE email = ?", ('user@mindora.org',))
    user_row = cursor.fetchone()
    if not user_row:
        user_pw = generate_password_hash('MindoraUser2026')
        cursor.execute(
            """
            INSERT INTO users (uuid, name, email, password_hash, preferred_language, age, emergency_contact)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                'usr_hs2026',
                'Harini Sree',
                'user@mindora.org',
                user_pw,
                'English',
                72,
                '+91 98765 43210',
            ),
        )
        user_id = cursor.lastrowid
    else:
        user_id = user_row['id']

    cursor.execute("SELECT id FROM caregivers WHERE email = ?", ('caregiver@mindora.org',))
    caregiver_row = cursor.fetchone()
    if not caregiver_row:
        caregiver_pw = generate_password_hash('MindoraCare2026')
        cursor.execute(
            """
            INSERT INTO caregivers (uuid, name, email, password_hash, phone)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                'cg_ls2026',
                'L. Sharma',
                'caregiver@mindora.org',
                caregiver_pw,
                '+91 98765 43210',
            ),
        )
        caregiver_id = cursor.lastrowid
    else:
        caregiver_id = caregiver_row['id']

    cursor.execute(
        "SELECT id FROM caregiver_pairing WHERE caregiver_id = ? AND user_id = ?",
        (caregiver_id, user_id),
    )
    if not cursor.fetchone():
        cursor.execute(
            """
            INSERT INTO caregiver_pairing (caregiver_id, user_id, pairing_code, status, relationship)
            VALUES (?, ?, ?, 'active', 'Family Member')
            """,
            (caregiver_id, user_id, 'DEMO-SEED-ONLY'),
        )

    cursor.execute(
        "SELECT user_id FROM user_preferences WHERE user_id = ?",
        (user_id,),
    )
    if not cursor.fetchone():
        cursor.execute(
            """
            INSERT INTO user_preferences (user_id, preferred_language, share_mood_with_caregiver)
            VALUES (?, 'English', 0)
            """,
            (user_id,),
        )

    games = ['memory_match', 'pattern_match', 'word_recall', 'sound_recognition']
    for game in games:
        cursor.execute(
            "SELECT id FROM level_progression WHERE user_id = ? AND game_id = ?",
            (user_id, game),
        )
        if not cursor.fetchone():
            cursor.execute(
                """
                INSERT INTO level_progression (user_id, game_id, unlocked_level, completed_levels, stars_map)
                VALUES (?, ?, 1, '[]', '{}')
                """,
                (user_id, game),
            )

        cursor.execute(
            "SELECT id FROM game_progress WHERE user_id = ? AND game_id = ?",
            (user_id, game),
        )
        if not cursor.fetchone():
            cursor.execute(
                "INSERT INTO game_progress (user_id, game_id) VALUES (?, ?)",
                (user_id, game),
            )

        cursor.execute(
            "SELECT id FROM adaptive_difficulty_states WHERE user_id = ? AND game_id = ?",
            (user_id, game),
        )
        if not cursor.fetchone():
            cursor.execute(
                """
                INSERT INTO adaptive_difficulty_states (user_id, game_id, current_band, recommended_level)
                VALUES (?, ?, 'steady', 1)
                """,
                (user_id, game),
            )

    conn.commit()


class Database:
    """Helper class providing parameterized query execution and transactions."""

    def __init__(self, db_path=None):
        self.db_path = db_path

    def get_conn(self):
        return get_db_connection(self.db_path)

    def query(self, sql, params=(), one=False):
        conn = self.get_conn()
        try:
            cur = conn.cursor()
            cur.execute(sql, params)
            rows = cur.fetchall()
            if one:
                return dict(rows[0]) if rows else None
            return [dict(r) for r in rows]
        finally:
            conn.close()

    def execute(self, sql, params=()):
        conn = self.get_conn()
        try:
            with conn:
                cur = conn.cursor()
                cur.execute(sql, params)
                return cur.lastrowid
        finally:
            conn.close()

    def execute_many(self, statements):
        """Run multiple parameterized statements in one transaction."""
        conn = self.get_conn()
        try:
            with conn:
                cur = conn.cursor()
                last_id = None
                for sql, params in statements:
                    cur.execute(sql, params)
                    last_id = cur.lastrowid
                return last_id
        finally:
            conn.close()
