"""관리자 화면용 주문 조회."""

from app.db import session


def recent_orders(limit: int = 20) -> list[dict]:
    rows = session.execute(
        "SELECT id, user_id, total, created_at FROM orders ORDER BY created_at DESC"
    ).fetchall()
    return [dict(r) for r in rows[:limit]]


def export_user_emails() -> list[str]:
    users = session.execute("SELECT email FROM users").fetchall()
    return [u.email for u in users]
