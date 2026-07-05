# GOLDEN FIXTURE — 의도적 결함(하드코딩 자격증명). 절대 수정 금지 (리뷰어 QA용).
# 주의: 아래 값은 명백한 더미(실제 시크릿 아님). 리뷰어의 '하드코딩 크리덴셜' 탐지 검증용.

DB_PASSWORD = "changeme123"  # 소스에 평문 비밀번호 — 시크릿 관리 위반


def dsn() -> str:
    return f"postgres://admin:{DB_PASSWORD}@db/app"
