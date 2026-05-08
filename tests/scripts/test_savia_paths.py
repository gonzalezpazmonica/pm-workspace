"""Tests for scripts/savia_paths.py — confidential path resolution.

Centralizes how N3 user-specific paths (docs_root, projects_dir) are
discovered. NO hardcoded org/user names allowed in production scripts.

Resolution order:
  1. Environment variable SAVIA_DOCS_ROOT (override for tests/CI)
  2. ~/.savia/savia-paths.json {"docs_root": "..."}
  3. Error with explicit message — no leak in fallback
"""
import importlib.util
import json
import os
import sys
import tempfile
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "savia_paths.py"


def _load():
    spec = importlib.util.spec_from_file_location("savia_paths", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_docs_root_from_env_var(monkeypatch):
    mod = _load()
    monkeypatch.setenv("SAVIA_DOCS_ROOT", r"D:/test/savia")
    assert mod.docs_root() == Path(r"D:/test/savia")


def test_docs_root_from_config_file(tmp_path, monkeypatch):
    mod = _load()
    monkeypatch.delenv("SAVIA_DOCS_ROOT", raising=False)
    cfg = tmp_path / "savia-paths.json"
    cfg.write_text(json.dumps({"docs_root": str(tmp_path / "savia")}), encoding="utf-8")
    monkeypatch.setattr(mod, "CONFIG_FILE", cfg)
    assert mod.docs_root() == tmp_path / "savia"


def test_docs_root_raises_when_not_configured(tmp_path, monkeypatch):
    mod = _load()
    monkeypatch.delenv("SAVIA_DOCS_ROOT", raising=False)
    monkeypatch.setattr(mod, "CONFIG_FILE", tmp_path / "missing.json")
    try:
        mod.docs_root()
        assert False, "expected ConfigError"
    except mod.ConfigError as e:
        assert "SAVIA_DOCS_ROOT" in str(e)


def test_project_paths_compose_codename(monkeypatch, tmp_path):
    mod = _load()
    monkeypatch.setenv("SAVIA_DOCS_ROOT", str(tmp_path))
    paths = mod.project_paths("Project X")
    assert paths["meetings"] == tmp_path / "projects" / "Project X_main" / "Project X-monica" / "meetings"
    assert paths["radar"] == tmp_path / "projects" / "Project X_main" / "Project X-monica" / "reports" / "radar"
    assert paths["pending"] == tmp_path / "projects" / "Project X_main" / "Project X-monica" / "notes" / "PENDING.md"


def test_no_real_names_in_module(monkeypatch):
    """Regression: this module itself MUST NOT hardcode org/user names."""
    src = SCRIPT.read_text(encoding="utf-8")
    forbidden = ["Some Private Company", "private.username", "OneDrive - "]
    for term in forbidden:
        assert term not in src, "forbidden token: " + term


if __name__ == "__main__":
    import pytest
    sys.exit(pytest.main([__file__, "-v"]))
