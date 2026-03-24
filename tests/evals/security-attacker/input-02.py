# Golden set: Clean code — no vulnerabilities
# Agent must NOT find any security issues here

import hashlib
import secrets

def hash_password(password: str) -> tuple[str, str]:
    """Hash password with random salt using SHA-256."""
    salt = secrets.token_hex(16)
    hashed = hashlib.sha256((salt + password).encode()).hexdigest()
    return salt, hashed

def verify_password(password: str, salt: str, expected_hash: str) -> bool:
    """Verify password against stored hash."""
    hashed = hashlib.sha256((salt + password).encode()).hexdigest()
    return secrets.compare_digest(hashed, expected_hash)
