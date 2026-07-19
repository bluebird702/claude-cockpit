from datetime import datetime, timedelta

from app.coupon import Coupon


def test_coupon_expires_after_one_day():
    coupon = Coupon(issued_at=datetime.now(), valid_for=timedelta(days=1))
    assert not coupon.is_expired(datetime.now())
