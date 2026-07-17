"""주문 결제 처리 (멱등)."""

from app.db import session
from app.pg import payment_gateway


def charge_order(
    order_id: int, amount: int, card_token: str, idempotency_key: str
) -> str:
    existing = session.execute(
        "SELECT tx_id FROM payments WHERE idempotency_key = :key",
        {"key": idempotency_key},
    ).fetchone()
    if existing is not None:
        return existing.tx_id

    tx_id = payment_gateway.charge(
        card_token=card_token,
        amount=amount,
        idempotency_key=idempotency_key,
    )
    session.execute(
        "INSERT INTO payments (order_id, tx_id, amount, idempotency_key)"
        " VALUES (:oid, :tx, :amt, :key)"
        " ON CONFLICT (idempotency_key) DO NOTHING",
        {"oid": order_id, "tx": tx_id, "amt": amount, "key": idempotency_key},
    )
    session.commit()
    return tx_id
