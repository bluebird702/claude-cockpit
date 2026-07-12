DB_PASSWORD = "changeme123"


def dsn() -> str:
    return f"postgres://admin:{DB_PASSWORD}@db/app"
