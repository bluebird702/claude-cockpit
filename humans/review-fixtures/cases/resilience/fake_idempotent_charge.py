"""주문 결제 처리 (멱등 키 수용)."""

import structlog

from app.db import session
from app.pg import payment_gateway

log = structlog.get_logger()


def charge_order(
    order_id: int, amount: int, card_token: str, idempotency_key: str
) -> str:
    log.info("charge_start", order_id=order_id, idempotency_key=idempotency_key)
    tx_id = payment_gateway.charge(card_token=card_token, amount=amount)
    session.execute(
        "INSERT INTO payments (order_id, tx_id, amount) VALUES (:oid, :tx, :amt)",
        {"oid": order_id, "tx": tx_id, "amt": amount},
    )
    session.commit()
    return tx_id
