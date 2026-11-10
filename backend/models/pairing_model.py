# Mindora Backend - Caregiver Pairing Model
import secrets
import string
from datetime import datetime, timedelta, timezone

from config import get_config
from database.db import Database
from models.user_model import UserModel

db = Database()

_CODE_ALPHABET = ''.join(c for c in string.ascii_uppercase + string.digits if c not in 'O0I1')


def _now():
    return datetime.now(timezone.utc)


class PairingModel:
    @staticmethod
    def get_paired_loved_ones(caregiver_id: int):
        return db.query(
            """
            SELECT u.id as user_id, u.uuid, u.name, u.email, u.preferred_language,
                   u.age, u.emergency_contact, cp.status, cp.relationship,
                   cp.paired_at
            FROM caregiver_pairing cp
            JOIN users u ON cp.user_id = u.id
            WHERE cp.caregiver_id = ? AND cp.status = 'active'
            ORDER BY cp.paired_at DESC
            """,
            (caregiver_id,),
        )

    @staticmethod
    def is_paired(caregiver_id: int, user_id: int) -> bool:
        row = db.query(
            """
            SELECT id FROM caregiver_pairing
            WHERE caregiver_id = ? AND user_id = ? AND status = 'active'
            """,
            (caregiver_id, user_id),
            one=True,
        )
        return row is not None

    @staticmethod
    def generate_pairing_code(user_id: int):
        """Create a single-use, expiring pairing code for a loved one."""
        db.execute(
            "UPDATE pairing_invites SET status = 'expired' WHERE user_id = ? AND status = 'pending'",
            (user_id,),
        )
        # 8 characters from a 32-symbol alphabet (~1.1e12 combinations).
        body = ''.join(secrets.choice(_CODE_ALPHABET) for _ in range(8))
        code = f'MIND-{body[:4]}-{body[4:]}'
        ttl = max(1, get_config().PAIRING_CODE_TTL_MINUTES)
        expires_at = (_now() + timedelta(minutes=ttl)).isoformat()
        db.execute(
            """
            INSERT INTO pairing_invites (user_id, pairing_code, status, expires_at)
            VALUES (?, ?, 'pending', ?)
            """,
            (user_id, code, expires_at),
        )
        return code

    @staticmethod
    def _is_expired(expires_at):
        if not expires_at:
            return True
        try:
            parsed = datetime.fromisoformat(str(expires_at).replace('Z', '+00:00'))
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=timezone.utc)
            return parsed < _now()
        except (TypeError, ValueError):
            return True

    @staticmethod
    def pair_with_code(caregiver_id: int, pairing_code: str, relationship: str = 'Family Member'):
        """Redeem a valid, unexpired, single-use pairing code."""
        code = (pairing_code or '').strip().upper()
        if not code:
            return None

        invite = db.query(
            """
            SELECT * FROM pairing_invites
            WHERE UPPER(pairing_code) = ? AND status = 'pending'
            """,
            (code,),
            one=True,
        )
        if not invite:
            return None

        if PairingModel._is_expired(invite.get('expires_at')):
            db.execute("UPDATE pairing_invites SET status = 'expired' WHERE id = ?", (invite['id'],))
            return None

        user_id = invite['user_id']

        # A pairing code is single-use and can only be redeemed once.
        conn = db.get_conn()
        try:
            with conn:
                updated = conn.execute(
                    "UPDATE pairing_invites SET status = 'used' WHERE id = ? AND status = 'pending'",
                    (invite['id'],),
                )
                if updated.rowcount != 1:
                    return None
                conn.execute(
                    """
                    INSERT INTO caregiver_pairing
                        (caregiver_id, user_id, pairing_code, status, relationship, paired_at)
                    VALUES (?, ?, ?, 'active', ?, CURRENT_TIMESTAMP)
                    ON CONFLICT(caregiver_id, user_id) DO UPDATE SET
                        status = 'active',
                        pairing_code = excluded.pairing_code,
                        relationship = excluded.relationship,
                        paired_at = CURRENT_TIMESTAMP
                    """,
                    (caregiver_id, user_id, code, (relationship or 'Family Member').strip()[:60]),
                )
        finally:
            conn.close()
        return UserModel.get_by_id(user_id)

    @staticmethod
    def revoke_pairing(caregiver_id: int, user_id: int) -> bool:
        """Revoke a caregiver's access to a loved one (unlink)."""
        conn = db.get_conn()
        try:
            with conn:
                cur = conn.execute(
                    """
                    UPDATE caregiver_pairing
                    SET status = 'revoked'
                    WHERE caregiver_id = ? AND user_id = ? AND status = 'active'
                    """,
                    (caregiver_id, user_id),
                )
                return cur.rowcount > 0
        finally:
            conn.close()

    @staticmethod
    def revoke_user_pairings(user_id: int) -> int:
        """Loved one can withdraw all caregiver access."""
        conn = db.get_conn()
        try:
            with conn:
                cur = conn.execute(
                    "UPDATE caregiver_pairing SET status = 'revoked' WHERE user_id = ? AND status = 'active'",
                    (user_id,),
                )
                return cur.rowcount
        finally:
            conn.close()

    @staticmethod
    def purge_expired_invites():
        conn = db.get_conn()
        try:
            with conn:
                conn.execute(
                    "UPDATE pairing_invites SET status = 'expired' WHERE status = 'pending' AND expires_at IS NOT NULL AND expires_at < ?",
                    (_now().isoformat(),),
                )
        finally:
            conn.close()
