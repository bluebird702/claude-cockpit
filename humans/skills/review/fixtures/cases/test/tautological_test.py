# GOLDEN FIXTURE — 의도적 결함(tautological 테스트, 결과 미단언). 절대 수정 금지 (리뷰어 QA용).


def process(x: int) -> int:
    return x * 2


def test_process_runs():
    # 호출만 하고 반환값을 전혀 단언하지 않음 → process 로직을 지워도 통과.
    process(3)
