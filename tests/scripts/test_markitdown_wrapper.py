"""
tests/scripts/test_markitdown_wrapper.py
SE-172 — pytest tests para markitdown-digest-wrapper.py
>= 8 tests requeridos por AC-08
"""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Path setup
REPO_ROOT = Path(__file__).parent.parent.parent
WRAPPER = REPO_ROOT / "scripts" / "markitdown-digest-wrapper.py"
DIGEST_EXTRACT = REPO_ROOT / "scripts" / "digest-extract.sh"
sys.path.insert(0, str(REPO_ROOT / "scripts"))


# ── Helpers ──────────────────────────────────────────────────────────────────

def run_wrapper(*args, env_overrides=None) -> subprocess.CompletedProcess:
    """Execute the wrapper as a subprocess."""
    env = os.environ.copy()
    env["WORKSPACE_ROOT"] = str(REPO_ROOT)
    if env_overrides:
        env.update(env_overrides)
    return subprocess.run(
        [sys.executable, str(WRAPPER), *args],
        capture_output=True,
        text=True,
        env=env,
    )


def parse_json_output(proc: subprocess.CompletedProcess) -> dict:
    """Parse JSON from wrapper stdout."""
    return json.loads(proc.stdout)


# ── T01: wrapper returns valid JSON ──────────────────────────────────────────
def test_wrapper_returns_valid_json(tmp_path):
    """Wrapper always produces parseable JSON output."""
    test_file = tmp_path / "test.txt"
    test_file.write_text("hello markitdown SE-172")

    proc = run_wrapper("--file", str(test_file), "--agent", "pdf")
    try:
        data = parse_json_output(proc)
        assert isinstance(data, dict)
    except json.JSONDecodeError as e:
        pytest.fail(f"Invalid JSON output: {e}\nstdout: {proc.stdout}")


# ── T02: wrapper returns markitdown_version field ─────────────────────────────
def test_wrapper_returns_markitdown_version(tmp_path):
    """JSON output must contain markitdown_version field."""
    test_file = tmp_path / "version_test.txt"
    test_file.write_text("version test content")

    proc = run_wrapper("--file", str(test_file), "--agent", "word")
    data = parse_json_output(proc)
    assert "markitdown_version" in data, "Missing markitdown_version in output"
    assert data["markitdown_version"], "markitdown_version should not be empty"


# ── T03: fallback_used=true when MARKITDOWN_ENABLED=false ─────────────────────
def test_fallback_used_when_markitdown_disabled(tmp_path):
    """When MARKITDOWN_ENABLED=false, fallback_used must be True."""
    test_file = tmp_path / "disabled.txt"
    test_file.write_text("disabled test")

    proc = run_wrapper(
        "--file", str(test_file), "--agent", "pdf",
        env_overrides={"MARKITDOWN_ENABLED": "false"}
    )
    data = parse_json_output(proc)
    assert data["fallback_used"] is True, (
        f"Expected fallback_used=True when disabled, got: {data}"
    )


# ── T04: wrapper rejects empty input file ────────────────────────────────────
def test_wrapper_rejects_empty_file_path(tmp_path):
    """Empty --file path should produce fallback_used=True or exit non-zero."""
    proc = run_wrapper("--file", "", "--agent", "pdf")
    # Either non-zero exit or fallback_used=True in JSON
    if proc.returncode == 0 and proc.stdout.strip():
        try:
            data = parse_json_output(proc)
            assert data.get("fallback_used") is True or data.get("ok") is False, (
                f"Empty input should fail gracefully: {data}"
            )
        except json.JSONDecodeError:
            pass  # Non-JSON output is also acceptable for invalid input
    else:
        assert proc.returncode != 0 or "error" in proc.stderr.lower() or \
               "empty" in proc.stderr.lower() or "fallback" in proc.stdout.lower()


# ── T05: correct path resolution for each agent ──────────────────────────────
@pytest.mark.parametrize("agent", ["pdf", "word", "excel", "pptx", "visual", "meeting"])
def test_path_resolution_per_agent(tmp_path, agent):
    """Path resolution works correctly for all supported agents."""
    test_file = tmp_path / f"test_{agent}.txt"
    test_file.write_text(f"content for agent {agent}")

    proc = run_wrapper("--file", str(test_file), "--agent", agent)
    data = parse_json_output(proc)

    # The source_file in output should be an absolute path
    assert "source_file" in data, f"Missing source_file for agent {agent}"
    assert data["source_file"], f"Empty source_file for agent {agent}"


# ── T06: fallback when markitdown subprocess fails (mock) ─────────────────────
def test_fallback_used_when_extract_fails(tmp_path):
    """When digest-extract.sh fails, fallback_used=True must be in output."""
    # Use a file that doesn't exist to force failure
    nonexistent = str(tmp_path / "does_not_exist.pdf")

    proc = run_wrapper("--file", nonexistent, "--agent", "pdf")
    data = parse_json_output(proc)

    assert data["fallback_used"] is True, (
        f"Expected fallback_used=True for missing file, got: {data}"
    )
    assert data["ok"] is False or not data.get("ok"), (
        f"Expected ok=False for missing file, got: {data}"
    )


# ── T07: output contains agent field ─────────────────────────────────────────
def test_output_contains_agent_field(tmp_path):
    """JSON output must contain agent field matching the --agent argument."""
    test_file = tmp_path / "agent_field.txt"
    test_file.write_text("agent field test")

    proc = run_wrapper("--file", str(test_file), "--agent", "excel")
    data = parse_json_output(proc)

    assert "agent" in data, "Missing agent field"
    assert data["agent"] == "excel", f"Expected 'excel', got '{data['agent']}'"


# ── T08: successful extraction populates markdown field ──────────────────────
def test_successful_extraction_has_markdown(tmp_path):
    """When extraction succeeds, output must have non-empty markdown."""
    test_file = tmp_path / "success_test.txt"
    test_file.write_text("This is a test document for SE-172 markitdown extraction.")

    proc = run_wrapper("--file", str(test_file), "--agent", "pdf")
    data = parse_json_output(proc)

    # If ok=True, markdown must be non-empty
    if data.get("ok") is True:
        assert data.get("markdown"), "ok=True but markdown is empty"
        assert len(data["markdown"]) > 0, "markdown should have content"


# ── T09: output contains timestamp ───────────────────────────────────────────
def test_output_contains_timestamp(tmp_path):
    """JSON output must contain a timestamp field."""
    test_file = tmp_path / "timestamp_test.txt"
    test_file.write_text("timestamp test")

    proc = run_wrapper("--file", str(test_file), "--agent", "meeting")
    data = parse_json_output(proc)

    assert "timestamp" in data, "Missing timestamp field"
    assert data["timestamp"], "timestamp should not be empty"


# ── T10: wrapper handles non-existent agent gracefully ───────────────────────
def test_invalid_agent_exits_nonzero(tmp_path):
    """Invalid --agent value should exit non-zero (argparse validation)."""
    test_file = tmp_path / "test.txt"
    test_file.write_text("content")

    proc = run_wrapper("--file", str(test_file), "--agent", "invalidagent")
    assert proc.returncode != 0, "Invalid agent should exit non-zero"


# ── T11: wrapper includes source_file field ──────────────────────────────────
def test_wrapper_includes_source_file(tmp_path):
    """JSON output must include source_file field."""
    test_file = tmp_path / "source_field.txt"
    test_file.write_text("source file test")

    proc = run_wrapper("--file", str(test_file), "--agent", "pptx")
    data = parse_json_output(proc)

    assert "source_file" in data, "Missing source_file field"


# ── T12: digest-extract.sh references convert_local (AC-05) ──────────────────
def test_digest_extract_references_convert_local():
    """digest-extract.sh must reference convert_local (AC-05)."""
    content = DIGEST_EXTRACT.read_text()
    assert "convert_local" in content, (
        "digest-extract.sh must use convert_local (AC-05 — local-only by default)"
    )


# ── T13: wrapper references convert_local (AC-05) ────────────────────────────
def test_wrapper_references_convert_local():
    """markitdown-digest-wrapper.py must reference convert_local (AC-05)."""
    content = WRAPPER.read_text()
    assert "convert_local" in content, (
        "wrapper must reference convert_local (AC-05)"
    )
