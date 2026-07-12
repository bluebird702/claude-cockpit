import logging

logger = logging.getLogger(__name__)


def load(path: str) -> str:
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        logger.error("failed to read %s", path)
        raise
