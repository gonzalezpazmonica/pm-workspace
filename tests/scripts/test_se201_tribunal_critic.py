"""Tests for SE-201 — Critic scoring cuantitativo en tribunales.

Covers:
- AC1: JSON output with score, breakdown (4 dimensions), feedback fields
- AC2: exit 0 when score >= threshold; exit 1 when score < threshold
- AC3: tribunal-critic mentioned in court-orchestrator.md
- AC4: --rubric flag accepts custom JSON rubric
- AC5: scores registered in output/tribunal-scores.jsonl with all fields
- AC6: feedback field present in JSON output
"""
from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
CRITIC_SH = ROOT / "scripts" / "tribunal-critic.sh"
COURT_ORCHESTRATOR = ROOT / ".opencode" / "agents" / "court-orchestrator.md"


def run_critic(*args, env=None, project_root=None, **kwargs):
    base_env = os.environ.copy()
    base_env["PROJECT_ROOT"] = str(project_root or ROOT)
    if env:
        base_env.update(env)
    return subprocess.run(
        ["bash", str(CRITIC_SH), *args],
        capture_output=True,
        text=True,
        env=base_env,
    )


def make_verdict(tmpdir: Path, content: str, name: str = "verdict.crc") -> Path:
    p = tmpdir / name
    p.write_text(content)
    return p


GOOD_VERDICT = """
Code Review Court Verdict

Summary: PASS — no CRITICAL issues.
Correctness: all tests pass. no blocker found.
Completeness: security auth credentials covered. spec tests coverage verified.
  performance complexity latency reviewed. error exception edge case null handled.
  API interface contract schema checked. logging monitoring tracing metric present.
Security: OWASP Top 10 reviewed. No injection XSS CSRF. CWE assessment done.
Spec Compliance: AC-1 through AC-7 verified. acceptance criteria met.
"""

WEAK_VERDICT = """
Code looks fine I guess.
"""


def test_critic_json_has_required_fields():
    """AC1: --json output contains score, breakdown with 4 dims, feedback."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tp = Path(tmpdir)
        v = make_verdict(tp, GOOD_VERDICT)
        r = run_critic("--json", str(v), project_root=tp)
        assert r.returncode == 0, f"stderr={r.stderr}"
        d = json.loads(r.stdout.strip())
        assert "score" in d
        assert "breakdown" in d
        assert "feedback" in d
        assert isinstance(d["score"], int)
        bd = d["breakdown"]
        for dim in ("correctness", "completeness", "security", "spec_compliance"):
            assert dim in bd, f"breakdown missing {dim}"


def test_critic_exit_0_passes():
    """AC2: exit 0 when score >= threshold."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tp = Path(tmpdir)
        v = make_verdict(tp, GOOD_VERDICT)
        r = run_critic("--json", str(v), project_root=tp,
                       env={"SAVIA_CRITIC_THRESHOLD": "1"})
        assert r.returncode == 0


def test_critic_exit_1_fails():
    """AC2: exit 1 when score < threshold."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tp = Path(tmpdir)
        v = make_verdict(tp, WEAK_VERDICT)
        r = run_critic("--json", str(v), project_root=tp,
                       env={"SAVIA_CRITIC_THRESHOLD": "80"})
        assert r.returncode == 1


def test_court_orchestrator_mentions_critic():
    """AC3: tribunal-critic appears in court-orchestrator.md."""
    assert COURT_ORCHESTRATOR.exists()
    assert "tribunal-critic" in COURT_ORCHESTRATOR.read_text()


def test_critic_custom_rubric():
    """AC4: --rubric JSON file is accepted without error."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tp = Path(tmpdir)
        rubric = tp / "r.json"
        rubric.write_text(json.dumps(
            {"correctness": 25, "completeness": 25, "security": 25, "spec_compliance": 25}
        ))
        v = make_verdict(tp, GOOD_VERDICT)
        r = run_critic("--json", "--rubric", str(rubric), str(v), project_root=tp)
        assert r.returncode == 0
        d = json.loads(r.stdout.strip())
        assert "score" in d


def test_critic_logs_scores_file():
    """AC5: execution appends entry to output/tribunal-scores.jsonl."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tp = Path(tmpdir)
        (tp / "output").mkdir()
        v = make_verdict(tp, GOOD_VERDICT)
        r = run_critic("--json", str(v), project_root=tp)
        assert r.returncode == 0
        sf = tp / "output" / "tribunal-scores.jsonl"
        assert sf.exists()
        entry = json.loads(sf.read_text().strip().splitlines()[-1])
        for field in ("timestamp", "score", "breakdown", "feedback"):
            assert field in entry, f"scores file missing field: {field}"


def test_critic_feedback_non_empty_on_weak_verdict():
    """AC6: feedback field non-empty when dimensions are incomplete."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tp = Path(tmpdir)
        v = make_verdict(tp, WEAK_VERDICT)
        r = run_critic("--json", str(v), project_root=tp,
                       env={"SAVIA_CRITIC_THRESHOLD": "1"})
        d = json.loads(r.stdout.strip())
        assert "feedback" in d
        assert d["feedback"]
