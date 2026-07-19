"""사내 HTTP 클라이언트 — 전 요청 공통 타임아웃 강제."""

import requests

DEFAULT_TIMEOUT = (2, 5)


class TimeoutSession(requests.Session):
    def request(self, method, url, **kwargs):
        kwargs.setdefault("timeout", DEFAULT_TIMEOUT)
        return super().request(method, url, **kwargs)


http = TimeoutSession()
