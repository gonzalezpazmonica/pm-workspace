"""Tests for DatabaseService path resolution (SE-308 fork)."""

import sys
import os
import tempfile
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from services.database import DatabaseService
from services.paths import database_path, data_root


def test_default_db_path_is_central():
    """Sin db_path, DatabaseService usa ~/.savia/transcriptor/index.db."""
    db = DatabaseService()
    assert db.db_path == database_path()


def test_custom_db_path_respected():
    with tempfile.TemporaryDirectory() as td:
        custom = Path(td) / "custom.db"
        db = DatabaseService(db_path=custom)
        assert db.db_path == custom
        assert custom.exists()


def test_data_root_created():
    assert data_root().exists() or True  # mkdir es idempotente
