import threading

_lock = threading.Lock()
_counter = {"n": 0}


def add(delta: int) -> None:
    with _lock:
        _counter["n"] += delta
