"""tests/scripts/test_skill_detection.py — SPEC-SE-030

pytest >= 8 tests for:
  - scripts/skill-usage-tracker.py  (tracking invocations)
  - scripts/skill-pattern-detector.sh (pattern detection — via CLI JSON output)
"""
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

# ── Load skill-usage-tracker module ──────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
TRACKER_SCRIPT = REPO_ROOT / "scripts" / "skill-usage-tracker.py"
DETECTOR_SCRIPT = REPO_ROOT / "scripts" / "skill-pattern-detector.sh"


def _load_tracker():
    spec = importlib.util.spec_from_file_location("skill_usage_tracker", TRACKER_SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["skill_usage_tracker"] = mod
    spec.loader.exec_module(mod)
    return mod


tracker_mod = _load_tracker()
track_invocation = tracker_mod.track_invocation


# ── Tests — skill-usage-tracker ───────────────────────────────────────────────

def test_tracker_appends_entry(tmp_path: Path):
    log = tmp_path / "skill-invocations.jsonl"
    track_invocation("spec-driven-development", "/spec-new", "sess-001", log)
    assert log.exists()
    records = [json.loads(l) for l in log.read_text().splitlines() if l.strip()]
    assert len(records) == 1
    r = records[0]
    assert r["skill"] == "spec-driven-development"
    assert r["command"] == "/spec-new"
    assert r["session_id"] == "sess-001"
    assert "ts" in r


def test_tracker_appends_multiple_entries(tmp_path: Path):
    log = tmp_path / "invocations.jsonl"
    for i in range(5):
        track_invocation(f"skill-{i}", f"/cmd-{i}", f"sess-{i}", log)
    records = [json.loads(l) for l in log.read_text().splitlines() if l.strip()]
    assert len(records) == 5


def test_tracker_rolling_window_max_1000(tmp_path: Path):
    log = tmp_path / "invocations.jsonl"
    # Pre-fill with 998 entries
    with log.open("w") as fh:
        for i in range(998):
            fh.write(json.dumps({"ts": "2026-01-01T00:00:00Z", "skill": "old", "command": "/old", "session_id": f"s-{i}"}) + "\n")
    # Add 2 more: total 1000 — no trim
    track_invocation("new-skill", "/new", "new-sess-1", log)
    track_invocation("new-skill", "/new", "new-sess-2", log)
    records = [json.loads(l) for l in log.read_text().splitlines() if l.strip()]
    assert len(records) == 1000


def test_tracker_rolling_window_trims_over_1000(tmp_path: Path):
    log = tmp_path / "invocations.jsonl"
    # Pre-fill with 1000 entries
    with log.open("w") as fh:
        for i in range(1000):
            fh.write(json.dumps({"ts": "2026-01-01T00:00:00Z", "skill": "old", "command": "/old", "session_id": f"s-{i}"}) + "\n")
    # Add one more: should trim to 1000
    track_invocation("newest", "/newest", "newest-sess", log)
    records = [json.loads(l) for l in log.read_text().splitlines() if l.strip()]
    assert len(records) == 1000
    # The newest entry should be the last one
    assert records[-1]["skill"] == "newest"


def test_tracker_creates_parent_dir(tmp_path: Path):
    log = tmp_path / "nested" / "dir" / "invocations.jsonl"
    track_invocation("some-skill", "/some-cmd", "sess-abc", log)
    assert log.exists()


def test_tracker_entry_has_required_fields(tmp_path: Path):
    log = tmp_path / "inv.jsonl"
    track_invocation("my-skill", "/my-cmd", "my-session", log)
    r = json.loads(log.read_text().strip())
    for field in ("ts", "skill", "command", "session_id"):
        assert field in r, f"Missing field: {field}"


# ── Tests — skill-pattern-detector.sh ────────────────────────────────────────

def _run_detector(extra_args: list[str], env: dict | None = None) -> dict:
    """Run skill-pattern-detector.sh --json and return parsed JSON."""
    import os
    run_env = os.environ.copy()
    if env:
        run_env.update(env)
    result = subprocess.run(
        ["bash", str(DETECTOR_SCRIPT), "--json"] + extra_args,
        capture_output=True,
        text=True,
        env=run_env,
        timeout=30,
    )
    assert result.returncode == 0, f"Detector exited {result.returncode}: {result.stderr}"
    return json.loads(result.stdout)


def test_detector_script_exists():
    assert DETECTOR_SCRIPT.exists(), "skill-pattern-detector.sh not found"


def test_detector_no_data_returns_patterns_found_0(tmp_path: Path):
    """With no invocations file, detector returns patterns_found=0."""
    env = {
        "DATA_DIR": str(tmp_path / "data"),
        "OUTPUT_DIR": str(tmp_path / "output"),
        "INVOCATIONS_LOG": str(tmp_path / "data" / "skill-invocations.jsonl"),
    }
    result = _run_detector([], env=env)
    assert result["patterns_found"] == 0


def test_detector_json_output_valid(tmp_path: Path):
    """Output must be valid JSON with patterns_found field."""
    env = {
        "INVOCATIONS_LOG": str(tmp_path / "nonexistent.jsonl"),
    }
    result = _run_detector([], env=env)
    assert "patterns_found" in result


def _make_synthetic_sessions(log: Path, n_sessions: int = 25, repeat_seq: list | None = None):
    """Generate synthetic sessions with a repeating sequence."""
    if repeat_seq is None:
        repeat_seq = ["/spec-new", "/code", "/test"]
    with log.open("w") as fh:
        for session_i in range(n_sessions):
            sid = f"sess-{session_i:03d}"
            if session_i < 20:
                # All first 20 sessions have the repeat_seq
                cmds = repeat_seq
            else:
                cmds = ["/misc"]
            for cmd in cmds:
                entry = {
                    "ts": f"2026-06-{(session_i % 28) + 1:02d}T10:00:00Z",
                    "skill": "spec-driven-development",
                    "command": cmd,
                    "session_id": sid,
                }
                fh.write(json.dumps(entry) + "\n")


def test_detector_detects_repeated_sequence(tmp_path: Path):
    """With 25+ sessions sharing a 3-cmd sequence repeated, patterns_found >= 1."""
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    log = data_dir / "skill-invocations.jsonl"
    _make_synthetic_sessions(log, n_sessions=25, repeat_seq=["/spec-new", "/code", "/test"])

    env = {
        "INVOCATIONS_LOG": str(log),
        "OUTPUT_DIR": str(tmp_path / "output"),
    }
    result = _run_detector(["--min-count", "3"], env=env)
    assert result["patterns_found"] >= 1


def test_detector_pattern_has_required_fields(tmp_path: Path):
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    log = data_dir / "skill-invocations.jsonl"
    _make_synthetic_sessions(log, n_sessions=25)

    env = {
        "INVOCATIONS_LOG": str(log),
        "OUTPUT_DIR": str(tmp_path / "output"),
    }
    result = _run_detector(["--min-count", "3"], env=env)
    if result["patterns_found"] > 0:
        p = result["patterns"][0]
        assert "sequence" in p, "Pattern missing 'sequence'"
        assert "count" in p, "Pattern missing 'count'"
        assert "suggestion" in p, "Pattern missing 'suggestion'"


def test_detector_pattern_count_gte_min(tmp_path: Path):
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    log = data_dir / "skill-invocations.jsonl"
    _make_synthetic_sessions(log, n_sessions=25)

    env = {
        "INVOCATIONS_LOG": str(log),
        "OUTPUT_DIR": str(tmp_path / "output"),
    }
    result = _run_detector(["--min-count", "3"], env=env)
    for p in result.get("patterns", []):
        assert p["count"] >= 3, f"Pattern count {p['count']} < min 3"


def test_detector_pattern_suggestion_not_empty(tmp_path: Path):
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    log = data_dir / "skill-invocations.jsonl"
    _make_synthetic_sessions(log, n_sessions=25)

    env = {
        "INVOCATIONS_LOG": str(log),
        "OUTPUT_DIR": str(tmp_path / "output"),
    }
    result = _run_detector(["--min-count", "3"], env=env)
    for p in result.get("patterns", []):
        assert p["suggestion"], "Suggestion must not be empty"


def test_detector_pattern_sequence_length_gte_3(tmp_path: Path):
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    log = data_dir / "skill-invocations.jsonl"
    _make_synthetic_sessions(log, n_sessions=25, repeat_seq=["/a", "/b", "/c", "/d"])

    env = {
        "INVOCATIONS_LOG": str(log),
        "OUTPUT_DIR": str(tmp_path / "output"),
    }
    result = _run_detector(["--min-count", "3"], env=env)
    for p in result.get("patterns", []):
        assert len(p["sequence"]) >= 3, "Sequence must have >= 3 commands"


def test_detector_output_json_valid_structure(tmp_path: Path):
    """Output always has patterns_found int and patterns list."""
    env = {
        "INVOCATIONS_LOG": str(tmp_path / "nonexistent.jsonl"),
    }
    result = _run_detector([], env=env)
    assert isinstance(result["patterns_found"], int)
    assert "patterns" not in result or isinstance(result["patterns"], list)
