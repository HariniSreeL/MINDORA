# Mindora Backend - Lightweight in-process login throttling
# Suitable for a single-process/small deployment. For multi-worker deployments use
# a shared store (Redis) instead; this still meaningfully slows brute-force attempts.
import threading
import time
from collections import defaultdict, deque

from config import get_config

_lock = threading.Lock()
_attempts = defaultdict(deque)


def _key(identifier: str) -> str:
    return (identifier or 'unknown').strip().lower()


def is_login_blocked(identifier: str):
    """Return (blocked, retry_after_seconds)."""
    config = get_config()
    window = max(30, config.LOGIN_WINDOW_SECONDS)
    limit = max(3, config.LOGIN_MAX_ATTEMPTS)
    now = time.time()
    key = _key(identifier)
    with _lock:
        entries = _attempts[key]
        while entries and entries[0] < now - window:
            entries.popleft()
        if len(entries) >= limit:
            return True, int(window - (now - entries[0])) + 1
    return False, 0


def record_failed_login(identifier: str) -> None:
    with _lock:
        _attempts[_key(identifier)].append(time.time())


def clear_login_attempts(identifier: str) -> None:
    with _lock:
        _attempts.pop(_key(identifier), None)
