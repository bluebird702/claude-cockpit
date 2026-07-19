"""주문 목록 API 응답 조립."""

from dataclasses import dataclass

from app.db import session


@dataclass
class OrderView:
    order_id: int
    user_name: str
    total: int


def list_orders(cursor: int | None, size: int = 50) -> list[OrderView]:
    orders = session.execute(
        "SELECT id, user_id, total FROM orders"
        " WHERE (:cursor IS NULL OR id < :cursor)"
        " ORDER BY id DESC LIMIT :size",
        {"cursor": cursor, "size": size},
    ).fetchall()

    views = []
    for order in orders:
        user = session.execute(
            "SELECT name FROM users WHERE id = :uid",
            {"uid": order.user_id},
        ).fetchone()
        views.append(
            OrderView(
                order_id=order.id,
                user_name=user.name,
                total=order.total,
            )
        )
    return views
