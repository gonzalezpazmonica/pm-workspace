"""Tests for LLM secret storage path (SE-308 fork)."""

import sys
import os
import tempfile
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from services.paths import secrets_path


def test_fallback_path_is_central():
    """El fallback JSON vive en ~/.savia/transcriptor/secrets.json."""
    assert secrets_path() == Path.home() / ".savia" / "transcriptor" / "secrets.json"


def test_fallback_writable():
    """El fallback path es escribible (directorio parent existe o se crea)."""
    parent = secrets_path().parent
    parent.mkdir(parents=True, exist_ok=True)
    assert parent.is_dir()
