import threading

_counter = {"n": 0}


def add(delta: int) -> None:
    current = _counter["n"]
    _counter["n"] = current + delta


def run(workers: int) -> None:
    ts = [threading.Thread(target=add, args=(1,)) for _ in range(workers)]
    for t in ts:
        t.start()
    for t in ts:
        t.join()
