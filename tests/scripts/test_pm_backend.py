"""
test_pm_backend.py -- SE-092 MVP tests for pm-backend-health.sh and pm-backend-query.py

Tests:
1. health-check: output is valid JSON with required fields
2. query mock: backend=none returns mock data
3. query PAT never appears in output
4. query sprint-status produces items array
5. query my-items produces items array
6. health-check: with full ADO config returns configured=True
7. query: --json flag produces parseable JSON
"""

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent.parent
HEALTH_SCRIPT = REPO_ROOT / "scripts" / "pm-backend-health.sh"
QUERY_SCRIPT = REPO_ROOT / "scripts" / "pm-backend-query.py"


# ── Test 1: health-check produces valid JSON ─────────────────────────────────

def test_health_check_valid_json():
    """pm-backend-health.sh always produces valid JSON."""
    result = subprocess.run(
        ["bash", str(HEALTH_SCRIPT)],
        capture_output=True,
        text=True,
        timeout=15,
        env={**os.environ},
    )
    assert result.returncode == 0, f"health.sh failed: {result.stderr}"
    data = json.loads(result.stdout)
    # Required fields
    assert "backend" in data
    assert "configured" in data
    assert "pat_file_exists" in data
    assert "project" in data
    assert "notes" in data
    # Type checks
    assert isinstance(data["configured"], bool)
    assert isinstance(data["pat_file_exists"], bool)
    assert data["backend"] in ("ado", "jira", "none")


# ── Test 2: query with no backend returns mock data ──────────────────────────

def test_query_mock_when_no_backend():
    """With backend=none, query returns mock data with note field."""
    env = {k: v for k, v in os.environ.items()
           if k not in ("AZURE_DEVOPS_ORG_URL", "AZURE_DEVOPS_PROJECT",
                        "AZURE_PAT", "AZURE_DEVOPS_EXT_PAT")}
    result = subprocess.run(
        [sys.executable, str(QUERY_SCRIPT), "--sprint-status", "--json"],
        capture_output=True,
        text=True,
        timeout=15,
        env=env,
    )
    assert result.returncode == 0, f"query failed: {result.stderr}"
    data = json.loads(result.stdout)
    assert "note" in data
    assert "mock" in data["note"].lower() or "not configured" in data["note"].lower()


# ── Test 3: PAT never appears in output ─────────────────────────────────────

def test_pat_never_in_output():
    """PAT value (if any) must never appear in health or query output."""
    # Create a fake PAT file with known value
    import tempfile
    fake_pat = "FAKE-TEST-PAT-VALUE-12345"
    with tempfile.NamedTemporaryFile(mode='w', suffix='.pat', delete=False) as f:
        f.write(fake_pat)
        pat_file = f.name

    try:
        env = {
            **os.environ,
            "AZURE_DEVOPS_PAT_FILE": pat_file,
            "AZURE_DEVOPS_ORG_URL": "https://dev.azure.com/testorg",
            "AZURE_DEVOPS_PROJECT": "TestProject",
        }
        # health check output
        health_result = subprocess.run(
            ["bash", str(HEALTH_SCRIPT)],
            capture_output=True, text=True, timeout=15, env=env,
        )
        assert fake_pat not in health_result.stdout, "PAT found in health output!"
        assert fake_pat not in health_result.stderr, "PAT found in health stderr!"

        # query mock output (mock mode to avoid real API call)
        query_result = subprocess.run(
            [sys.executable, str(QUERY_SCRIPT), "--mock", "--sprint-status", "--json"],
            capture_output=True, text=True, timeout=15, env=env,
        )
        assert fake_pat not in query_result.stdout, "PAT found in query output!"
        assert fake_pat not in query_result.stderr, "PAT found in query stderr!"
    finally:
        os.unlink(pat_file)


# ── Test 4: sprint-status produces items array ────────────────────────────────

def test_sprint_status_produces_items_array():
    """--sprint-status JSON output has an 'items' array."""
    result = subprocess.run(
        [sys.executable, str(QUERY_SCRIPT), "--sprint-status", "--json"],
        capture_output=True, text=True, timeout=15,
    )
    assert result.returncode == 0, f"query failed: {result.stderr}"
    data = json.loads(result.stdout)
    assert "items" in data
    assert isinstance(data["items"], list)


# ── Test 5: my-items produces items array ────────────────────────────────────

def test_my_items_produces_items_array():
    """--my-items JSON output has an 'items' array."""
    result = subprocess.run(
        [sys.executable, str(QUERY_SCRIPT), "--my-items", "--json"],
        capture_output=True, text=True, timeout=15,
    )
    assert result.returncode == 0, f"query failed: {result.stderr}"
    data = json.loads(result.stdout)
    assert "items" in data
    assert isinstance(data["items"], list)
    assert len(data["items"]) > 0, "my-items should return at least 1 mock item"


# ── Test 6: health-check with ADO config returns ado backend ─────────────────

def test_health_check_ado_config():
    """With ADO env vars set, health-check reports ado backend."""
    import tempfile
    fake_pat = "FAKE-PAT-FOR-TEST"
    with tempfile.NamedTemporaryFile(mode='w', suffix='.pat', delete=False) as f:
        f.write(fake_pat)
        pat_file = f.name
    try:
        env = {
            **os.environ,
            "AZURE_DEVOPS_ORG_URL": "https://dev.azure.com/mytestorg",
            "AZURE_DEVOPS_PROJECT": "TestProject",
            "AZURE_DEVOPS_PAT_FILE": pat_file,
        }
        result = subprocess.run(
            ["bash", str(HEALTH_SCRIPT)],
            capture_output=True, text=True, timeout=15, env=env,
        )
        assert result.returncode == 0
        data = json.loads(result.stdout)
        assert data["backend"] == "ado"
        assert data["configured"] is True
        assert data["pat_file_exists"] is True
        assert data["project"] == "TestProject"
    finally:
        os.unlink(pat_file)


# ── Test 7: --json flag on query produces parseable JSON ─────────────────────

def test_query_json_flag_parseable():
    """--json flag always produces parseable JSON with sprint-status and my-items."""
    for cmd in ["--sprint-status", "--my-items"]:
        result = subprocess.run(
            [sys.executable, str(QUERY_SCRIPT), cmd, "--json"],
            capture_output=True, text=True, timeout=15,
        )
        assert result.returncode == 0, f"query {cmd} failed: {result.stderr}"
        data = json.loads(result.stdout)
        assert isinstance(data, dict), f"{cmd} JSON is not a dict"
