"""알림 발송 — 지수 백오프 재시도."""

import random
import time

import requests

WEBHOOK_URL = "https://notify.internal/hooks/orders"
MAX_ATTEMPTS = 5
BASE_DELAY = 0.5


def send_notification(payload: dict) -> bool:
    for attempt in range(MAX_ATTEMPTS):
        try:
            resp = requests.post(WEBHOOK_URL, json=payload, timeout=5)
            if resp.status_code < 500:
                return True
        except requests.ConnectionError:
            pass
        delay = BASE_DELAY * (2**attempt) + random.uniform(0, 0.3)
        time.sleep(delay)
    return False
