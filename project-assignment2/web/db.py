# web/db.py
# Expects web/login.py to define: credentials = "dbname=... user=... password=... host=... port=..."

from contextlib import contextmanager
import psycopg2

try:
    import login
except ImportError as e:
    raise ImportError(
        "Missing login.py - no 'credentials' string."
        ) from e


@contextmanager
def connect():
    """
    Usage:
        with db.connect() as conn:
            with conn:
                with conn.cursor() as cur:
                    cur.execute(...)
    """
    conn = psycopg2.connect(login.credentials)
    try:
        yield conn
    finally:
        try:
            conn.close()
        except Exception:
            pass
