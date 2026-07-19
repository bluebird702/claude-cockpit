"""외부 재고 서비스 클라이언트."""

import requests

INVENTORY_BASE = "https://inventory.internal/api/v1"


def get_stock(sku: str) -> int:
    resp = requests.get(f"{INVENTORY_BASE}/stock/{sku}")
    resp.raise_for_status()
    return resp.json()["quantity"]


def reserve(sku: str, quantity: int) -> bool:
    resp = requests.post(
        f"{INVENTORY_BASE}/reservations",
        json={"sku": sku, "quantity": quantity},
    )
    return resp.status_code == 201
