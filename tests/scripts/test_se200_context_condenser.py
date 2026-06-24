"""Tests for SE-200 — LLM Condenser: rolling window context compression.

Covers:
- AC1: exit 0 when session log <= max_size; no output written
- AC2: exit 0 when session log is absent (no crash)
- AC3: --dry-run shows indices without writing files
- AC4: SAVIA_CONDENSER_MAX_SIZE env var is respected
- AC5: Condensation entry written to output/condensations-YYYYMMDD.jsonl
- AC6: head and tail are preserved intact
- AC7: PostTurn hook registered in .claude/settings.json
- AC8: Python condenser produces valid JSON condensation entry
- AC9: condensation entry has all required fields
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from datetime import datetime, timezone

import pytest

ROOT = Path(__file__).resolve().parents[2]
CONDENSER_SH = ROOT / "scripts" / "context-condenser.sh"
CONDENSER_PY = ROOT / "scripts" / "context-condenser.py"
SETTINGS_JSON = ROOT / ".claude" / "settings.json"


def run_sh(*args, env=None, **kwargs):
    base_env = os.environ.copy()
    if env:
        base_env.update(env)
    return subprocess.run(
        ["bash", str(CONDENSER_SH), *args],
        capture_output=True,
        text=True,
        env=base_env,
        **kwargs,
    )


def run_py(*args, env=None, **kwargs):
    base_env = os.environ.copy()
    if env:
        base_env.update(env)
    return subprocess.run(
        [sys.executable, str(CONDENSER_PY), *args],
        capture_output=True,
        text=True,
        env=base_env,
        **kwargs,
    )


def make_session_log(path: Path, n_lines: int) -> None:
    """Write n_lines of fake JSONL events to path."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        for i in range(n_lines):
            f.write(json.dumps({"type": "action", "index": i}) + "\n")


# ── AC7: PostTurn hook registered ───────────────────────────────────────────

def test_postturn_hook_registered_se200():
    """AC3: PostTurn hook for context-condenser is in .claude/settings.json."""
    assert SETTINGS_JSON.exists(), f"settings.json not found at {SETTINGS_JSON}"
    data = json.loads(SETTINGS_JSON.read_text())
    hooks = data.get("hooks", {})
    postturn = hooks.get("PostTurn", [])
    assert postturn, "PostTurn key missing from hooks"
    # Find context-condenser mention
    found = False
    for entry in postturn:
        for hook in entry.get("hooks", []):
            if "context-condenser" in hook.get("command", ""):
                found = True
    assert found, "context-condenser.sh not found in PostTurn hooks"


# ── AC1/AC7: exit 0 when log < max_size (no-op) ─────────────────────────────

def test_condenser_noop_when_below_threshold():
    """AC7: script exits 0 and writes nothing when events <= max_size."""
    with tempfile.TemporaryDirectory() as tmpdir:
        log_path = Path(tmpdir) / "session-action-log.jsonl"
        make_session_log(log_path, 10)
        result = run_sh(
            "--session-log", str(log_path),
            env={"SAVIA_CONDENSER_MAX_SIZE": "120"},
        )
        assert result.returncode == 0
        # No condensation files should be written
        condensations = list(Path(tmpdir).glob("condensations-*.jsonl"))
        assert not condensations, "Should write no files when below threshold"


# ── AC2: missing session log exits cleanly ──────────────────────────────────

def test_condenser_missing_log_exits_cleanly():
    """AC7: script exits 0 gracefully when session log not found."""
    with tempfile.TemporaryDirectory() as tmpdir:
        result = run_sh(
            "--session-log", str(Path(tmpdir) / "nonexistent.jsonl"),
        )
        assert result.returncode == 0


# ── AC6/AC3: --dry-run shows segment info without writing ───────────────────

def test_condenser_dry_run_no_write():
    """AC6: --dry-run outputs segment info and writes no files."""
    with tempfile.TemporaryDirectory() as tmpdir:
        log_path = Path(tmpdir) / "session-action-log.jsonl"
        make_session_log(log_path, 130)
        result = run_sh(
            "--dry-run",
            "--session-log", str(log_path),
            env={"SAVIA_CONDENSER_MAX_SIZE": "120",
                 "SAVIA_CONDENSER_KEEP_HEAD": "4",
                 "SAVIA_CONDENSER_KEEP_TAIL": "60"},
        )
        assert result.returncode == 0
        assert "DRY RUN" in result.stdout or "dry" in result.stdout.lower()
        # No output files written
        condensations = list(Path(tmpdir).glob("condensations-*.jsonl"))
        assert not condensations


# ── AC4: SAVIA_CONDENSER_MAX_SIZE env var respected ─────────────────────────

def test_condenser_max_size_env():
    """AC4: SAVIA_CONDENSER_MAX_SIZE overrides default threshold."""
    with tempfile.TemporaryDirectory() as tmpdir:
        log_path = Path(tmpdir) / "session-action-log.jsonl"
        make_session_log(log_path, 15)  # 15 lines
        # With max_size=10, 15 > 10 → dry-run should show compression
        result = run_sh(
            "--dry-run",
            "--session-log", str(log_path),
            env={"SAVIA_CONDENSER_MAX_SIZE": "10",
                 "SAVIA_CONDENSER_KEEP_HEAD": "2",
                 "SAVIA_CONDENSER_KEEP_TAIL": "5"},
        )
        assert result.returncode == 0
        assert "DRY RUN" in result.stdout or "compress" in result.stdout.lower()


# ── AC5/AC9: Python condenser writes valid condensation entry ────────────────

def test_python_condenser_writes_condensation_entry():
    """AC5: condensation entry written with all required fields."""
    with tempfile.TemporaryDirectory() as tmpdir:
        log_path = Path(tmpdir) / "session-action-log.jsonl"
        make_session_log(log_path, 130)
        result = run_py(
            "--log", str(log_path),
            "--max-size", "120",
            "--keep-head", "4",
            "--keep-tail", "60",
        )
        assert result.returncode == 0, f"stderr: {result.stderr}"
        # Find condensation file
        date_str = datetime.now(timezone.utc).strftime("%Y%m%d")
        condensation_file = Path(tmpdir) / f"condensations-{date_str}.jsonl"
        assert condensation_file.exists(), "Condensation file not created"
        entry = json.loads(condensation_file.read_text().strip().splitlines()[0])
        # AC5: required fields
        assert "timestamp" in entry
        assert "session_id" in entry
        assert "events_total" in entry
        assert "events_condensed" in entry
        assert "summary" in entry


# ── AC2: head and tail preserved ────────────────────────────────────────────

def test_python_condenser_preserves_head_and_tail():
    """AC2: head (4) and tail (60) events preserved intact after condensation."""
    with tempfile.TemporaryDirectory() as tmpdir:
        log_path = Path(tmpdir) / "session-action-log.jsonl"
        n = 130
        make_session_log(log_path, n)
        # Remember original head/tail
        with open(log_path) as f:
            original_lines = f.readlines()
        head_orig = original_lines[:4]
        tail_orig = original_lines[-60:]

        run_py(
            "--log", str(log_path),
            "--max-size", "120",
            "--keep-head", "4",
            "--keep-tail", "60",
        )

        with open(log_path) as f:
            new_lines = f.readlines()

        # First 4 lines should match original head
        assert new_lines[:4] == head_orig, "Head not preserved"
        # Last 60 lines should match original tail
        assert new_lines[-60:] == tail_orig, "Tail not preserved"
