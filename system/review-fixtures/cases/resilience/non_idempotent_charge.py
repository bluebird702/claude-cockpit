"""주문 결제 처리."""

from app.db import session
from app.pg import payment_gateway


def charge_order(order_id: int, amount: int, card_token: str) -> str:
    tx_id = payment_gateway.charge(card_token=card_token, amount=amount)
    session.execute(
        "INSERT INTO payments (order_id, tx_id, amount) VALUES (:oid, :tx, :amt)",
        {"oid": order_id, "tx": tx_id, "amt": amount},
    )
    session.commit()
    return tx_id
