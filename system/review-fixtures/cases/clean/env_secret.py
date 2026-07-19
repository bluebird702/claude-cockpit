import os

DB_PASSWORD = os.environ["DB_PASSWORD"]


def dsn() -> str:
    return f"postgres://admin:{DB_PASSWORD}@db/app"
