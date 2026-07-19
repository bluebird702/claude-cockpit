"""알림 발송 — 실패 시 재시도."""

import requests

WEBHOOK_URL = "https://notify.internal/hooks/orders"


def send_notification(payload: dict) -> None:
    while True:
        try:
            resp = requests.post(WEBHOOK_URL, json=payload, timeout=5)
            if resp.status_code < 500:
                return
        except requests.ConnectionError:
            pass
