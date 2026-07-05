# GOLDEN FIXTURE — 의도적 결함(예외 삼키기). 절대 수정 금지 (리뷰어 QA용).


def load(path: str) -> str | None:
    try:
        with open(path) as f:
            return f.read()
    except Exception:
        pass  # 복구·로깅·재전파 없이 삼킴 → silent failure
    return None
