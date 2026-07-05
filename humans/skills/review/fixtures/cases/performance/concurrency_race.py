# GOLDEN FIXTURE — 의도적 결함(동시성 경합). 절대 수정 금지 (리뷰어 QA용).
import threading

_counter = {"n": 0}


def add(delta: int) -> None:
    # 공유 상태를 락 없이 read-modify-write → 여러 스레드 동시 진입 시 lost update.
    current = _counter["n"]
    _counter["n"] = current + delta


def run(workers: int) -> None:
    ts = [threading.Thread(target=add, args=(1,)) for _ in range(workers)]
    for t in ts:
        t.start()
    for t in ts:
        t.join()
