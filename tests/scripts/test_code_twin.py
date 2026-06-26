"""
tests/scripts/test_code_twin.py — SPEC-190 pytest suite

Tests:
  1.  code-twin-generate.py generates CTF with correct frontmatter for a Python file
  2.  Generated CTF has a function table section
  3.  Generated CTF has stale_after_days field
  4.  code-twin-sync-check: fresh CTF → stale_count=0
  5.  code-twin-sync-check: stale CTF → stale_count > 0
  6.  manifest.yaml has required fields (via init.sh)
  7.  generate: Python import detection (imports appear in depends_on)
  8.  generate: C# basic support (class + method names extracted)
  9.  generate: TypeScript support (class with decorator)
 10.  --json output is valid JSON with required keys
"""

import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
from datetime import date, timedelta

import pytest

REPO = pathlib.Path(__file__).parent.parent.parent
GENERATE = REPO / "scripts" / "code-twin-generate.py"
SYNC_CHECK = REPO / "scripts" / "code-twin-sync-check.sh"
INIT = REPO / "scripts" / "code-twin-init.sh"
TS_SAMPLE = REPO / "tests" / "fixtures" / "ts-sample"
CS_SAMPLE = REPO / "tests" / "fixtures" / "cs-sample"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _run_generate(src_file: str, output_dir: str, lang: str = None) -> subprocess.CompletedProcess:
    cmd = [sys.executable, str(GENERATE), "--file", src_file, "--output", output_dir]
    if lang:
        cmd += ["--lang", lang]
    return subprocess.run(cmd, capture_output=True, text=True)


def _make_python_file(tmp: str, imports: list = None, classes: list = None) -> str:
    imports = imports or ["os", "re"]
    classes = classes or [("MyService", ["do_work", "validate"])]
    lines = [f"import {i}" for i in imports]
    lines.append("")
    for cls, methods in classes:
        lines.append(f"class {cls}:")
        for m in methods:
            lines.append(f"    def {m}(self, x: int) -> str:")
            lines.append(f"        return str(x)")
        lines.append("")
    path = os.path.join(tmp, "service.py")
    pathlib.Path(path).write_text("\n".join(lines))
    return path


def _make_fresh_ctf(twin_dir: str, module_id: str = "FreshModule") -> str:
    """Create a CTF with last_sync = today (fresh)."""
    os.makedirs(twin_dir, exist_ok=True)
    today = date.today().isoformat()
    content = f"""---
module_id: {module_id}
layer: application
version: "1.0.0"
last_sync: "{today}"
token_budget: 200
stale_after_days: 7
depends_on: []
provides:
  - doSomething
status: STABLE
---
# {module_id}
"""
    path = os.path.join(twin_dir, f"{module_id}.md")
    pathlib.Path(path).write_text(content)
    return path


def _make_stale_ctf(twin_dir: str, module_id: str = "StaleModule") -> str:
    """Create a CTF with last_sync = 30 days ago (stale with stale_after_days=7)."""
    os.makedirs(twin_dir, exist_ok=True)
    old_date = (date.today() - timedelta(days=30)).isoformat()
    content = f"""---
module_id: {module_id}
layer: application
version: "1.0.0"
last_sync: "{old_date}"
token_budget: 200
stale_after_days: 7
depends_on: []
provides:
  - doSomething
status: STABLE
---
# {module_id}
"""
    path = os.path.join(twin_dir, f"{module_id}.md")
    pathlib.Path(path).write_text(content)
    return path


# ---------------------------------------------------------------------------
# Test 1: CTF generated with correct frontmatter for Python file
# ---------------------------------------------------------------------------

def test_generate_python_ctf_has_frontmatter():
    with tempfile.TemporaryDirectory() as tmp:
        src = _make_python_file(tmp)
        out = os.path.join(tmp, "out")
        result = _run_generate(src, out, lang="python")
        assert result.returncode == 0, f"generate failed: {result.stderr}"

        ctf_files = list(pathlib.Path(out).glob("*.md"))
        assert len(ctf_files) >= 1, "no CTF files generated"

        content = ctf_files[0].read_text()
        assert "module_id:" in content, "frontmatter missing module_id"
        assert "layer:" in content, "frontmatter missing layer"
        assert "version:" in content, "frontmatter missing version"
        assert "last_sync:" in content, "frontmatter missing last_sync"
        assert "token_budget:" in content, "frontmatter missing token_budget"
        assert "depends_on:" in content, "frontmatter missing depends_on"
        assert "provides:" in content, "frontmatter missing provides"
        assert "stale_after_days:" in content, "frontmatter missing stale_after_days"


# ---------------------------------------------------------------------------
# Test 2: Generated CTF has a function table section
# ---------------------------------------------------------------------------

def test_generate_python_ctf_has_function_table():
    with tempfile.TemporaryDirectory() as tmp:
        src = _make_python_file(tmp, classes=[("OrderService", ["create_order", "cancel_order", "get_order"])])
        out = os.path.join(tmp, "out")
        _run_generate(src, out, lang="python")

        ctf_files = list(pathlib.Path(out).glob("*.md"))
        assert ctf_files, "no CTF generated"
        content = ctf_files[0].read_text()

        # Should have a functions/methods section or table
        has_table = "Functions" in content or "Methods" in content or "| `" in content
        has_provides = "create_order" in content or "cancel_order" in content
        assert has_table or has_provides, (
            "CTF should contain a function listing or table"
        )


# ---------------------------------------------------------------------------
# Test 3: Generated CTF has stale_after_days field
# ---------------------------------------------------------------------------

def test_generate_ctf_has_stale_after_days():
    with tempfile.TemporaryDirectory() as tmp:
        src = _make_python_file(tmp)
        out = os.path.join(tmp, "out")
        _run_generate(src, out, lang="python")

        ctf_files = list(pathlib.Path(out).glob("*.md"))
        assert ctf_files
        content = ctf_files[0].read_text()
        match = re.search(r"^stale_after_days:\s*(\d+)", content, re.MULTILINE)
        assert match, "stale_after_days not found in CTF"
        days = int(match.group(1))
        assert days > 0, f"stale_after_days must be > 0, got {days}"


# ---------------------------------------------------------------------------
# Test 4: sync-check: fresh CTF → stale_count=0
# ---------------------------------------------------------------------------

def test_sync_check_fresh_ctf_stale_count_zero():
    with tempfile.TemporaryDirectory() as tmp:
        twin_dir = os.path.join(tmp, "twin")
        _make_fresh_ctf(twin_dir)

        result = subprocess.run(
            ["bash", str(SYNC_CHECK), twin_dir, "--json"],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, f"sync-check failed unexpectedly: {result.stdout}"
        data = json.loads(result.stdout)
        assert data["stale_count"] == 0, f"Expected 0 stale, got {data['stale_count']}"
        assert data["total_ctfs"] >= 1


# ---------------------------------------------------------------------------
# Test 5: sync-check: stale CTF → stale_count > 0
# ---------------------------------------------------------------------------

def test_sync_check_stale_ctf_stale_count_nonzero():
    with tempfile.TemporaryDirectory() as tmp:
        twin_dir = os.path.join(tmp, "twin")
        _make_stale_ctf(twin_dir)

        result = subprocess.run(
            ["bash", str(SYNC_CHECK), twin_dir, "--json"],
            capture_output=True, text=True,
        )
        assert result.returncode == 1, "Expected exit 1 for stale CTF"
        data = json.loads(result.stdout)
        assert data["stale_count"] > 0, f"Expected >0 stale, got {data['stale_count']}"


# ---------------------------------------------------------------------------
# Test 6: manifest.yaml has required fields (via init.sh)
# ---------------------------------------------------------------------------

def test_init_manifest_has_required_fields():
    with tempfile.TemporaryDirectory() as tmp:
        project_dir = os.path.join(tmp, "myproject")
        os.makedirs(project_dir)

        result = subprocess.run(
            ["bash", str(INIT), project_dir],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, f"init.sh failed: {result.stdout} {result.stderr}"

        manifest_path = os.path.join(project_dir, "code-twin", "manifest.yaml")
        assert os.path.isfile(manifest_path), "manifest.yaml not generated"
        content = pathlib.Path(manifest_path).read_text()

        for field in ("version:", "created:", "project:", "language:", "modules:"):
            assert field in content, f"manifest.yaml missing field: {field}"


# ---------------------------------------------------------------------------
# Test 7: generate: Python import detection
# ---------------------------------------------------------------------------

def test_generate_python_import_detection():
    with tempfile.TemporaryDirectory() as tmp:
        src = _make_python_file(tmp, imports=["requests", "sqlalchemy", "pydantic"])
        out = os.path.join(tmp, "out")
        _run_generate(src, out, lang="python")

        ctf_files = list(pathlib.Path(out).glob("*.md"))
        assert ctf_files
        content = ctf_files[0].read_text()
        # At least one of the imports should appear in depends_on or the CTF body
        has_imports = any(pkg in content for pkg in ("requests", "sqlalchemy", "pydantic"))
        assert has_imports, "No imports detected in generated CTF"


# ---------------------------------------------------------------------------
# Test 8: generate: C# basic support (class + method names)
# ---------------------------------------------------------------------------

def test_generate_csharp_basic_support():
    cs_file = CS_SAMPLE / "Project.Application" / "UserService.cs"
    if not cs_file.exists():
        pytest.skip(f"C# fixture not found: {cs_file}")

    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "out")
        result = _run_generate(str(cs_file), out, lang="csharp")
        assert result.returncode == 0, f"generate failed for C#: {result.stderr}"

        ctf_files = list(pathlib.Path(out).glob("*.md"))
        assert ctf_files, "No CTF generated for C# file"
        content = ctf_files[0].read_text()

        # Class name should appear
        assert "UserService" in content, "Class name not in CTF"
        # At least one method name should be detected
        has_method = any(m in content for m in ("FindByEmail", "Create", "Disable",
                                                  "FindByEmailAsync", "CreateAsync", "DisableAsync"))
        assert has_method, f"No method names detected in C# CTF. Content:\n{content[:500]}"
        # layer should be application (from namespace Project.Application)
        assert "application" in content, "Layer 'application' not in C# CTF"


# ---------------------------------------------------------------------------
# Test 9: generate: TypeScript support
# ---------------------------------------------------------------------------

def test_generate_typescript_support():
    ts_file = TS_SAMPLE / "user.service.ts"
    if not ts_file.exists():
        pytest.skip(f"TypeScript fixture not found: {ts_file}")

    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "out")
        result = _run_generate(str(ts_file), out, lang="typescript")
        assert result.returncode == 0, f"generate failed for TypeScript: {result.stderr}"

        ctf_files = list(pathlib.Path(out).glob("*.md"))
        assert ctf_files, "No CTF generated for TypeScript file"
        content = ctf_files[0].read_text()

        # Class name should appear
        assert "UserService" in content, "Class name not in TS CTF"
        # @Injectable → layer application
        assert "application" in content, "Layer 'application' not in TS CTF"
        # method names
        has_method = any(m in content for m in ("findById", "findByEmail", "create", "disable"))
        assert has_method, f"No method names detected in TS CTF. Content:\n{content[:500]}"


# ---------------------------------------------------------------------------
# Test 10: --json output is valid JSON with required keys
# ---------------------------------------------------------------------------

def test_sync_check_json_output_valid():
    with tempfile.TemporaryDirectory() as tmp:
        twin_dir = os.path.join(tmp, "twin")
        # Mix fresh and stale
        _make_fresh_ctf(twin_dir, "FreshA")
        _make_stale_ctf(twin_dir, "StaleB")

        result = subprocess.run(
            ["bash", str(SYNC_CHECK), "--twin-dir", twin_dir, "--json"],
            capture_output=True, text=True,
        )
        # returncode can be 0 or 1 depending on staleness
        assert result.stdout.strip(), "No JSON output"
        data = json.loads(result.stdout)

        required_keys = {"total_ctfs", "stale_count", "fresh_count", "stale_files"}
        missing = required_keys - set(data.keys())
        assert not missing, f"JSON missing keys: {missing}"
        assert isinstance(data["stale_files"], list)
        assert data["total_ctfs"] == data["stale_count"] + data["fresh_count"]
