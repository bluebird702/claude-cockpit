"""요청 카운트 집계 — PlainCounter 의 유일한 사용처."""

import threading

from cases.clean.plain_counter import PlainCounter

_lock = threading.Lock()
_counter = PlainCounter()


def record_request(count: int = 1) -> None:
    with _lock:
        _counter.increment(count)


def snapshot() -> int:
    with _lock:
        return _counter.value
