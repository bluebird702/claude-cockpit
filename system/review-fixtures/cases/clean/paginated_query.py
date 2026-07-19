"""주문 목록 조회 (커서 기반)."""

from app.db import session

MAX_PAGE_SIZE = 100


def list_orders(cursor: int | None, size: int = 20) -> dict:
    size = min(size, MAX_PAGE_SIZE)
    rows = session.execute(
        "SELECT id, user_id, total FROM orders"
        " WHERE (:cursor IS NULL OR id < :cursor)"
        " ORDER BY id DESC LIMIT :size",
        {"cursor": cursor, "size": size + 1},
    ).fetchall()

    has_next = len(rows) > size
    items = [dict(r) for r in rows[:size]]
    next_cursor = items[-1]["id"] if has_next and items else None
    return {"content": items, "nextCursor": next_cursor}
