# GOLDEN FIXTURE — 의도적 결함(도메인이 웹 프레임워크에 의존). 절대 수정 금지 (리뷰어 QA용).
# 경로가 domain/ 계층임에 유의 — 의존성 규칙(밖→안)상 프레임워크 import 금지.
from fastapi import Depends  # 도메인 계층이 프레임워크에 의존 → Clean Architecture 위반


class Order:
    def __init__(self, total: int, discount: "Depends" = None) -> None:
        self.total = total
        self.discount = discount
