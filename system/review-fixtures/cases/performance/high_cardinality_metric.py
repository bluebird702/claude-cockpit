"""요청 처리 메트릭 수집."""

from prometheus_client import Counter, Histogram

REQUEST_LATENCY = Histogram(
    "api_request_latency_seconds",
    "Request latency",
    ["endpoint", "user_id"],
)
REQUEST_ERRORS = Counter(
    "api_request_errors_total",
    "Request errors",
    ["endpoint", "user_email", "raw_url"],
)


def record_request(endpoint: str, user_id: str, elapsed: float) -> None:
    REQUEST_LATENCY.labels(endpoint=endpoint, user_id=user_id).observe(elapsed)


def record_error(endpoint: str, user_email: str, raw_url: str) -> None:
    REQUEST_ERRORS.labels(
        endpoint=endpoint,
        user_email=user_email,
        raw_url=raw_url,
    ).inc()
