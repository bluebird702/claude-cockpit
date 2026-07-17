"""인기 상품 목록 캐시."""

import json

from app.cache import redis_client
from app.db import session

CACHE_KEY = "popular_products"
TTL_SECONDS = 60


def get_popular_products() -> list[dict]:
    cached = redis_client.get(CACHE_KEY)
    if cached is not None:
        return json.loads(cached)

    rows = session.execute(
        "SELECT id, name, score FROM products ORDER BY score DESC LIMIT 100"
    ).fetchall()
    result = [dict(r) for r in rows]
    redis_client.setex(CACHE_KEY, TTL_SECONDS, json.dumps(result, default=str))
    return result
