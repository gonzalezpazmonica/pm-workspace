"""Tests for SE-202 — Agent-based semantic hooks.

Covers:
- AC1: --dry-run shows agent name and event without executing
- AC2: exit 0 for allow; exit 2 for deny (fail-closed when agent missing)
- AC3: --list-agents lists agents from .opencode/agents/
- AC4: SAVIA_AGENT_HOOK_TIMEOUT env var is accepted
- AC5: SAVIA_AGENT_HOOK_FAIL_OPEN controls allow/deny on missing agent
- AC6: decisions logged to output/agent-hook-decisions.jsonl
- AC7: SE-202 doc entry exists in settings.json
- AC8: agent-hook-protocol.md exists with exit code reference
"""
from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
RUNNER_SH = ROOT / "scripts" / "agent-hook-runner.sh"
SETTINGS_JSON = ROOT / ".claude" / "settings.json"
PROTOCOL_DOC = ROOT / "docs" / "rules" / "domain" / "agent-hook-protocol.md"


def run_runner(*args, env=None, project_root=None):
    base_env = os.environ.copy()
    base_env["PROJECT_ROOT"] = str(project_root or ROOT)
    if env:
        base_env.update(env)
    return subprocess.run(
        ["bash", str(RUNNER_SH), *args],
        capture_output=True, text=True, env=base_env,
    )


def test_dry_run_shows_agent_and_event():
    """AC1: --dry-run prints agent name without actual invocation."""
    r = run_runner(
        "--dry-run", "--agent", "security-guardian",
        "--event", '{"tool":"Bash","input":"ls /tmp"}',
    )
    assert r.returncode == 0
    out = r.stdout + r.stderr
    assert "security-guardian" in out
    assert "DRY" in out.upper() or "dry" in out.lower()


def test_fail_open_allows_missing_agent():
    """AC5: FAIL_OPEN=true -> exit 0 when agent file not found."""
    r = run_runner(
        "--agent", "nonexistent-xyz",
        "--event", '{"tool":"Bash","input":"date"}',
        env={"SAVIA_AGENT_HOOK_FAIL_OPEN": "true"},
    )
    assert r.returncode == 0


def test_fail_closed_denies_missing_agent():
    """AC5: FAIL_OPEN=false -> exit 2 when agent file not found."""
    r = run_runner(
        "--agent", "nonexistent-xyz",
        "--event", '{"tool":"Bash","input":"date"}',
        env={"SAVIA_AGENT_HOOK_FAIL_OPEN": "false"},
    )
    assert r.returncode == 2


def test_list_agents_exits_zero():
    """AC3: --list-agents exits 0 and outputs something."""
    r = run_runner("--list-agents")
    assert r.returncode == 0
    assert len(r.stdout.strip()) > 0


def test_hook_decisions_logged():
    """AC6: decision logged to output/agent-hook-decisions.jsonl."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tp = Path(tmpdir)
        (tp / "output").mkdir()
        r = run_runner(
            "--agent", "nonexistent-xyz",
            "--event", '{"tool":"Bash","input":"date"}',
            env={
                "SAVIA_AGENT_HOOK_FAIL_OPEN": "true",
                "PROJECT_ROOT": str(tp),
            },
            project_root=tp,
        )
        log_file = tp / "output" / "agent-hook-decisions.jsonl"
        assert log_file.exists(), "agent-hook-decisions.jsonl not created"
        entry = json.loads(log_file.read_text().strip().splitlines()[-1])
        for field in ("timestamp", "agent", "tool", "decision", "reason", "duration_ms"):
            assert field in entry, f"missing field: {field}"


def test_settings_json_has_se202_doc():
    """AC7: _doc_se202_example in settings.json references agent-hook-runner."""
    assert SETTINGS_JSON.exists()
    data = json.loads(SETTINGS_JSON.read_text())
    assert "_doc_se202_example" in data
    assert "agent-hook-runner" in data["_doc_se202_example"]


def test_protocol_doc_exists():
    """AC8: agent-hook-protocol.md exists and mentions exit codes."""
    assert PROTOCOL_DOC.exists()
    content = PROTOCOL_DOC.read_text()
    assert "exit" in content.lower()


def test_timeout_env_accepted():
    """AC4: SAVIA_AGENT_HOOK_TIMEOUT env var does not crash dry-run."""
    r = run_runner(
        "--dry-run", "--agent", "security-guardian",
        "--event", '{"tool":"Bash","input":"date"}',
        env={"SAVIA_AGENT_HOOK_TIMEOUT": "15"},
    )
    assert r.returncode == 0
