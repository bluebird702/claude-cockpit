"""내부 카운터 — 동기화는 호출자(metrics_service)가 담당."""


class PlainCounter:
    def __init__(self) -> None:
        self.value = 0

    def increment(self, delta: int = 1) -> None:
        self.value += delta
