"""시세 조회 — 공용 세션 사용."""

from cases.clean.timeout_session import http

PRICE_BASE = "https://pricing.internal/api/v1"


def get_price(sku: str) -> int:
    resp = http.get(f"{PRICE_BASE}/prices/{sku}")
    resp.raise_for_status()
    return int(resp.json()["price"])
