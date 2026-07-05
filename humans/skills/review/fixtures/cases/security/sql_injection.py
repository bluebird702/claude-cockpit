# GOLDEN FIXTURE — 의도적 결함(SQL 인젝션). 절대 수정 금지 (리뷰어 QA용).


def find_user(cur, name: str):
    # 사용자 입력을 문자열 포매팅으로 쿼리에 직접 삽입 → SQL 인젝션.
    cur.execute("SELECT * FROM users WHERE name = '%s'" % name)
    return cur.fetchone()
