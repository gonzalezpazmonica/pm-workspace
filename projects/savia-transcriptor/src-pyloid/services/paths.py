"""Central path resolution for Savia Transcriptor.

All data lives under `~/.savia/transcriptor/` (N3 local, never in a repo).

Savia Transcriptor is a fork of VoiceFlow (MIT). Upstream used `~/.VoiceFlow`;
we centralise the base path here so a future relocation is a one-line change.
"""

from __future__ import annotations

from pathlib import Path

APP_DIRNAME = "transcriptor"
BASE_DIR = Path.home() / ".savia" / APP_DIRNAME


def data_root() -> Path:
    """Top-level data directory: ~/.savia/transcriptor/."""
    return BASE_DIR


def recordings_dir() -> Path:
    """Where meeting recordings live: ~/.savia/transcriptor/recordings/."""
    return data_root() / "recordings"


def database_path() -> Path:
    """SQLite index database."""
    return data_root() / "index.db"


def log_path() -> Path:
    """Application log file."""
    return data_root() / "transcriptor.log"


def secrets_path() -> Path:
    """Local secrets (LLM keys), chmod 0600."""
    return data_root() / "secrets.json"


def cuda_dir() -> Path:
    """CUDA/cuDNN cache directory."""
    return data_root() / "cuda"


def meetings_dir() -> Path:
    """Meeting sessions: ~/.savia/transcriptor/reuniones/YYYY-MM-DD-HH-MM/."""
    return data_root() / "reuniones"
