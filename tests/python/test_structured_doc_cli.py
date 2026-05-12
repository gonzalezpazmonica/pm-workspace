"""CLI integration tests via subprocess (uses bootstrap registry)."""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _run(*args, expect_code=None):
    cmd = [sys.executable, "-m", "structured_doc", *args]
    env = {"PYTHONPATH": str(ROOT / "scripts" / "lib"), "PATH": "/usr/bin:/bin"}
    import os
    env["PATH"] = os.environ.get("PATH", "/usr/bin:/bin")
    r = subprocess.run(cmd, cwd=ROOT, env={**os.environ, **env},
                       capture_output=True, text=True)
    if expect_code is not None:
        assert r.returncode == expect_code, f"exit={r.returncode}\nstdout={r.stdout}\nstderr={r.stderr}"
    return r


def test_cli_list_types_includes_spec_md():
    r = _run("list-types", expect_code=0)
    data = json.loads(r.stdout)
    assert "spec-md" in data["types"]


def test_cli_lint_clean_spec_returns_zero():
    r = _run("lint", "spec-md", "docs/specs/SPEC-AGENT-ARCHITECT.spec.md",
             expect_code=0)
    data = json.loads(r.stdout)
    assert data["summary"]["errors"] == 0


def test_cli_human_output_emits_lines():
    r = _run("lint", "spec-md", "docs/specs/SPEC-AGENT-ARCHITECT.spec.md",
             "--human", expect_code=0)
    assert "errors=" in r.stdout
