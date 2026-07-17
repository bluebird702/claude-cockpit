import time
from datetime import datetime, timedelta

from app.coupon import Coupon


def test_coupon_expires_after_one_day():
    coupon = Coupon(issued_at=datetime.now(), valid_for=timedelta(days=1))
    assert not coupon.is_expired(datetime.now())


def test_coupon_not_expired_right_after_issue():
    coupon = Coupon(issued_at=datetime.now(), valid_for=timedelta(seconds=1))
    time.sleep(0.5)
    assert not coupon.is_expired(datetime.now())
