import secrets
import string

_ALPHABET = string.ascii_letters + string.digits


def generate_code(length: int = 7) -> str:
    """Return a random URL-safe alphanumeric code."""
    return "".join(secrets.choice(_ALPHABET) for _ in range(length))
