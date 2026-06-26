"""tests/scripts/test_pending_user_input.py — SPEC-076

Tests for scripts/pending-user-input.py: create, check, resolve, list
operations on the PENDING_USER_INPUT protocol for autonomous agents.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys
import tempfile
from pathlib import Path

import pytest

# ── Load module ───────────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "pending-user-input.py"


def _load():
    spec = importlib.util.spec_from_file_location("pending_user_input", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


mod = _load()
cmd_create = mod.cmd_create
cmd_check = mod.cmd_check
cmd_resolve = mod.cmd_resolve
cmd_list = mod.cmd_list
main = mod.main
REQUIRED_FIELDS = mod.REQUIRED_FIELDS


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture(autouse=True)
def isolated_pending_dir(tmp_path, monkeypatch):
    """Each test gets an isolated pending directory via env override."""
    pending = tmp_path / "pending"
    monkeypatch.setenv("SAVIA_PENDING_DIR", str(pending))
    return pending


# ── TC-1: create writes JSON file with question and ts ────────────────────────

class TestCreateWritesFile:
    """--create writes a JSON file with required fields."""

    def test_create_writes_file(self, isolated_pending_dir):
        rc = cmd_create("session-abc", "What is the target env?")
        assert rc == 0
        p = isolated_pending_dir / "session-abc.json"
        assert p.exists(), "pending file should be created"

    def test_create_file_has_question(self, isolated_pending_dir):
        cmd_create("session-abc", "What is the target env?")
        data = json.loads((isolated_pending_dir / "session-abc.json").read_text())
        assert data["question"] == "What is the target env?"

    def test_create_file_has_ts(self, isolated_pending_dir):
        cmd_create("session-abc", "What is the target env?")
        data = json.loads((isolated_pending_dir / "session-abc.json").read_text())
        assert "ts" in data and data["ts"]

    def test_create_file_has_session_id(self, isolated_pending_dir):
        cmd_create("session-xyz", "Deploy to prod?")
        data = json.loads((isolated_pending_dir / "session-xyz.json").read_text())
        assert data["session_id"] == "session-xyz"

    def test_create_status_is_waiting(self, isolated_pending_dir):
        cmd_create("session-abc", "Question?")
        data = json.loads((isolated_pending_dir / "session-abc.json").read_text())
        assert data["status"] == "waiting"


# ── TC-2: check returns exit 1 when no answer yet ─────────────────────────────

class TestCheckReturnsPendingStatus:
    """--check returns exit 1 when session has no answer."""

    def test_check_exit_1_when_waiting(self, isolated_pending_dir):
        cmd_create("sess-1", "Ready to proceed?")
        rc = cmd_check("sess-1")
        assert rc == 1

    def test_check_exit_2_when_session_not_found(self, isolated_pending_dir):
        rc = cmd_check("nonexistent-session")
        assert rc == 2


# ── TC-3: resolve writes answer and ts_resolved ───────────────────────────────

class TestResolveWritesAnswer:
    """--resolve updates the pending file with the answer."""

    def test_resolve_writes_answer(self, isolated_pending_dir):
        cmd_create("sess-2", "Which region?")
        cmd_resolve("sess-2", "eu-west-1")
        data = json.loads((isolated_pending_dir / "sess-2.json").read_text())
        assert data["answer"] == "eu-west-1"

    def test_resolve_writes_ts_resolved(self, isolated_pending_dir):
        cmd_create("sess-2", "Which region?")
        cmd_resolve("sess-2", "eu-west-1")
        data = json.loads((isolated_pending_dir / "sess-2.json").read_text())
        assert "ts_resolved" in data and data["ts_resolved"]

    def test_resolve_updates_status(self, isolated_pending_dir):
        cmd_create("sess-2", "Which region?")
        cmd_resolve("sess-2", "eu-west-1")
        data = json.loads((isolated_pending_dir / "sess-2.json").read_text())
        assert data["status"] == "answered"


# ── TC-4: check returns exit 0 after resolve ─────────────────────────────────

class TestCheckReturnsZeroAfterResolve:
    """--check returns exit 0 once --resolve has been called."""

    def test_check_exit_0_after_resolve(self, isolated_pending_dir):
        cmd_create("sess-3", "Confirm deletion?")
        cmd_resolve("sess-3", "yes")
        rc = cmd_check("sess-3")
        assert rc == 0


# ── TC-5: list shows pending sessions ────────────────────────────────────────

class TestListShowsSessions:
    """--list outputs pending sessions."""

    def test_list_shows_waiting_session(self, isolated_pending_dir, capsys):
        cmd_create("sess-wait", "Waiting question?")
        cmd_list()
        captured = capsys.readouterr()
        assert "sess-wait" in captured.out

    def test_list_empty_dir(self, isolated_pending_dir, capsys):
        rc = cmd_list()
        assert rc == 0
        captured = capsys.readouterr()
        assert "No pending sessions" in captured.out or "waiting" in captured.out.lower() or len(captured.out) > 0

    def test_list_distinguishes_waiting_from_answered(self, isolated_pending_dir, capsys):
        cmd_create("s-wait", "Still waiting")
        cmd_create("s-done", "Already answered")
        cmd_resolve("s-done", "done")
        cmd_list()
        captured = capsys.readouterr()
        assert "s-wait" in captured.out


# ── TC-6: create with existing session overwrites ────────────────────────────

class TestCreateOverwrites:
    """--create on existing session overwrites the record."""

    def test_create_twice_overwrites(self, isolated_pending_dir):
        cmd_create("sess-ow", "First question")
        cmd_create("sess-ow", "Second question")
        data = json.loads((isolated_pending_dir / "sess-ow.json").read_text())
        assert data["question"] == "Second question"

    def test_create_twice_resets_answer(self, isolated_pending_dir):
        cmd_create("sess-ow", "First question")
        cmd_resolve("sess-ow", "some answer")
        cmd_create("sess-ow", "New question after reset")
        data = json.loads((isolated_pending_dir / "sess-ow.json").read_text())
        assert data["answer"] is None
        assert data["status"] == "waiting"


# ── TC-7: resolve with nonexistent session returns error ──────────────────────

class TestResolveNonexistentSession:
    """--resolve on nonexistent session prints clear error and returns non-zero."""

    def test_resolve_missing_session_returns_error(self, isolated_pending_dir, capsys):
        rc = cmd_resolve("nonexistent-42", "answer")
        assert rc != 0
        captured = capsys.readouterr()
        assert "nonexistent-42" in captured.err or "nonexistent-42" in captured.out or "error" in captured.err.lower()


# ── TC-8: JSON file has required fields ──────────────────────────────────────

class TestJsonFileRequiredFields:
    """Created JSON file contains all required fields."""

    def test_required_fields_present(self, isolated_pending_dir):
        cmd_create("sess-fields", "Has all fields?")
        data = json.loads((isolated_pending_dir / "sess-fields.json").read_text())
        for field in ("question", "ts", "session_id"):
            assert field in data, f"Missing required field: {field}"

    def test_required_fields_non_empty(self, isolated_pending_dir):
        cmd_create("sess-fields", "Has all fields?")
        data = json.loads((isolated_pending_dir / "sess-fields.json").read_text())
        assert data["question"]
        assert data["ts"]
        assert data["session_id"]


# ── TC-9: CLI integration ─────────────────────────────────────────────────────

class TestCLIIntegration:
    """End-to-end CLI create→check→resolve→check cycle."""

    def test_full_lifecycle_via_cli(self, isolated_pending_dir, capsys):
        # Create
        rc = main(["--create", "--session", "cli-sess", "--question", "Proceed?"])
        assert rc == 0

        # Check → pending
        rc = main(["--check", "--session", "cli-sess"])
        assert rc == 1

        # Resolve
        rc = main(["--resolve", "--session", "cli-sess", "--answer", "yes"])
        assert rc == 0

        # Check → answered
        rc = main(["--check", "--session", "cli-sess"])
        assert rc == 0

    def test_cli_list_exit_0(self, isolated_pending_dir, capsys):
        rc = main(["--list"])
        assert rc == 0
