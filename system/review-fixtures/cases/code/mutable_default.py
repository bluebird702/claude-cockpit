"""주문 태그 부여."""


def add_tags(order_id: int, tags: list[str] = []) -> list[str]:
    tags.append(f"order:{order_id}")
    return tags


def build_filters(base: dict = {}) -> dict:
    base.setdefault("status", "ACTIVE")
    return base
