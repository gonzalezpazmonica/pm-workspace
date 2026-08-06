"""Tests for central path resolution (SE-308)."""

from pathlib import Path
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from services.paths import (
    BASE_DIR,
    data_root,
    recordings_dir,
    database_path,
    log_path,
    secrets_path,
    cuda_dir,
    meetings_dir,
)


def test_base_dir_under_savia():
    assert BASE_DIR == Path.home() / ".savia" / "transcriptor"


def test_data_root_matches_base():
    assert data_root() == BASE_DIR


def test_recordings_dir():
    assert recordings_dir() == data_root() / "recordings"


def test_database_path():
    assert database_path() == data_root() / "index.db"


def test_log_path():
    assert log_path() == data_root() / "transcriptor.log"


def test_secrets_path():
    assert secrets_path() == data_root() / "secrets.json"


def test_cuda_dir():
    assert cuda_dir() == data_root() / "cuda"


def test_meetings_dir():
    assert meetings_dir() == data_root() / "reuniones"


def test_meetings_dir_matches_recordings_convention():
    # recordings/ es el nombre del upstream; reuniones/ es la convencion Savia.
    # Ambos coexisten: reuniones/ para sesiones VAD, recordings/ para grabaciones manuales.
    assert meetings_dir() == data_root() / "reuniones"
