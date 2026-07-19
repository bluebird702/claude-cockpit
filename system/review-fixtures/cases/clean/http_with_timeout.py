"""외부 환율 서비스 클라이언트."""

import requests

FX_BASE = "https://fx.internal/api/v1"
CONNECT_TIMEOUT = 2
READ_TIMEOUT = 5


def get_rate(base: str, quote: str) -> float:
    resp = requests.get(
        f"{FX_BASE}/rates/{base}/{quote}",
        timeout=(CONNECT_TIMEOUT, READ_TIMEOUT),
    )
    resp.raise_for_status()
    return float(resp.json()["rate"])
