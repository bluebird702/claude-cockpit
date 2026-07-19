def load(path: str) -> str | None:
    try:
        with open(path) as f:
            return f.read()
    except Exception:
        pass
    return None
