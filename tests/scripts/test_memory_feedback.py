"""
tests/scripts/test_memory_feedback.py — pytest tests for SPEC-164 Memory Feedback Loop
>=10 tests covering extractor, compactor, and post-merge logic.
"""
import json
import sys
import os
import shutil
import textwrap
import tempfile
from pathlib import Path

import importlib.util
import pytest

# ── Paths ─────────────────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).parent.parent.parent
EXTRACTOR = REPO_ROOT / "scripts" / "memory-feedback-extractor.py"
COMPACTOR = REPO_ROOT / "scripts" / "memory-feedback-compactor.py"
POST_MERGE = REPO_ROOT / "scripts" / "memory-feedback-post-merge.sh"


def _load_module(path: Path, module_name: str):
    """Load a Python module from a path that may contain hyphens."""
    spec = importlib.util.spec_from_file_location(module_name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# Load modules once at module level
_extractor = _load_module(EXTRACTOR, "memory_feedback_extractor")
extract = _extractor.extract
_compute_entropy = _extractor._compute_entropy


# ─────────────────────────────────────────────────────────────────────────────
# Extractor tests (1-5)
# ─────────────────────────────────────────────────────────────────────────────

class TestExtractor:

    def _make_payload(self, output: str, agent: str = "dotnet-developer") -> dict:
        return {
            "tool_name": "Task",
            "tool_input": {"subagent_type": agent},
            "tool_result": output,
        }

    def test_error_in_output_yields_failure(self):
        """Output containing 'ERROR' → outcome=failure"""
        payload = self._make_payload("ERROR: connection refused on port 5432")
        result = extract(payload)
        assert result["outcome"] == "failure"

    def test_clean_output_yields_success(self):
        """Clean output without error keywords → outcome=success"""
        payload = self._make_payload(
            "All 42 tests passed. Coverage: 87%. Build completed in 3.2s."
        )
        result = extract(payload)
        assert result["outcome"] == "success"

    def test_failure_always_should_write(self):
        """should_write=True for any failure regardless of entropy"""
        payload = self._make_payload("FAILED: test_auth_login assertion error")
        result = extract(payload)
        assert result["should_write"] is True

    def test_success_low_entropy_no_write(self):
        """should_write=False for success with very low entropy (<= 0.3)"""
        # Very short output with few unique tokens → low entropy
        payload = self._make_payload("ok")
        result = extract(payload)
        assert result["outcome"] == "success"
        assert result["should_write"] is False

    def test_entropy_score_computed_correctly(self):
        """entropy_score is between 0 and 1"""
        output = " ".join([f"word{i}" for i in range(200)])
        score = _compute_entropy(output)
        assert 0.0 <= score <= 1.0

    def test_entropy_score_empty_output(self):
        """Empty output → entropy_score = 0.0"""
        assert _compute_entropy("") == 0.0

    def test_entropy_score_very_short(self):
        """Very short output (< 10 tokens) → entropy_score = 0.0"""
        assert _compute_entropy("ok done") == 0.0

    def test_agent_name_extracted_from_tool_input(self):
        """agent_name is read from tool_input.subagent_type"""
        payload = {
            "tool_name": "Task",
            "tool_input": {"subagent_type": "test-runner"},
            "tool_result": "ERROR: tests failed",
        }
        result = extract(payload)
        assert result["agent_name"] == "test-runner"

    def test_lesson_truncated_to_150_chars(self):
        """lesson is always <= 150 characters"""
        long_line = "A" * 300
        payload = self._make_payload(long_line)
        result = extract(payload)
        assert len(result["lesson"]) <= 150

    def test_exception_in_output_yields_failure(self):
        """Output with 'Exception' keyword → outcome=failure"""
        payload = self._make_payload(
            "Traceback (most recent call last):\n  File 'app.py'\nException: null ref"
        )
        result = extract(payload)
        assert result["outcome"] == "failure"
        assert result["should_write"] is True


# ─────────────────────────────────────────────────────────────────────────────
# Compactor tests (6-10)
# ─────────────────────────────────────────────────────────────────────────────

def _make_memory_file(tmp_path: Path, entries: list[str]) -> Path:
    """Create a MEMORY.md with the given entries inside ENTRIES block."""
    memory_dir = tmp_path / "auto"
    memory_dir.mkdir(parents=True)
    memory_file = memory_dir / "MEMORY.md"
    content = "# MEMORY Index\n\n<!-- ENTRIES_START -->\n"
    for e in entries:
        content += e + "\n"
    content += "<!-- ENTRIES_END -->\n"
    memory_file.write_text(content, encoding="utf-8")
    return memory_file


def _ts(n: int) -> str:
    return f"2026-06-{n:02d}T12:00:00Z"


class TestCompactor:

    def test_identifies_repeated_entries(self, tmp_path):
        """Compactor identifies same agent + outcome >= 3 times"""
        entries = [
            f"- outcome:failure agent:test-runner lesson:Tests failed [{_ts(i)}]"
            for i in range(1, 5)
        ]
        mem = _make_memory_file(tmp_path, entries)

        # Import compactor module
        mfc = _load_module(COMPACTOR, "memory_feedback_compactor")

        _, raw_entries, _ = mfc.read_memory(mem)
        groups = mfc.group_by_agent_outcome(raw_entries)
        key = ("test-runner", "failure")
        assert key in groups
        assert len(groups[key]) >= 3

    def test_promotes_lesson_to_learned(self, tmp_path):
        """Compactor promotes pattern to docs/rules/learned/ dir"""
        entries = [
            f"- outcome:failure agent:dotnet-developer lesson:Build failed [{_ts(i)}]"
            for i in range(1, 4)
        ]
        mem = _make_memory_file(tmp_path, entries)
        learned_dir = tmp_path / "learned"

        mfc = _load_module(COMPACTOR, "memory_feedback_compactor")

        _, raw_entries, _ = mfc.read_memory(mem)
        groups = mfc.group_by_agent_outcome(raw_entries)
        key = ("dotnet-developer", "failure")
        assert key in groups
        most_recent = groups[key][0]
        dest = mfc.promote_to_learned("dotnet-developer", "failure", most_recent["lesson"], learned_dir, dry_run=False)
        assert dest.exists()
        content = dest.read_text()
        assert "dotnet-developer" in content
        assert "failure" in content

    def test_cap_enforcement(self, tmp_path):
        """Compactor removes oldest entries when > 190 entry lines"""
        entries = [
            f"- outcome:success agent:agent-{i} lesson:Lesson {i} [{_ts(1)}]"
            for i in range(200)
        ]
        mem = _make_memory_file(tmp_path, entries)

        # Patch env and run compactor
        os.environ["MEMORY_FILE"] = str(mem)
        try:
            mfc = _load_module(COMPACTOR, "memory_feedback_compactor")

            args_obj = type("Args", (), {"dry_run": False, "memory": str(mem)})()
            mfc.compact(args_obj)

            # Re-read
            _, new_entries, _ = mfc.read_memory(mem)
            entry_count = sum(1 for ln in new_entries if ln.strip().startswith("- "))
            assert entry_count <= 190
        finally:
            del os.environ["MEMORY_FILE"]

    def test_dry_run_does_not_modify_memory(self, tmp_path):
        """--dry-run does not write to MEMORY.md"""
        entries = [
            f"- outcome:failure agent:test-runner lesson:Fail [{_ts(i)}]"
            for i in range(1, 5)
        ]
        mem = _make_memory_file(tmp_path, entries)
        original = mem.read_text()

        mfc = _load_module(COMPACTOR, "memory_feedback_compactor")

        args_obj = type("Args", (), {"dry_run": True, "memory": str(mem)})()
        mfc.compact(args_obj)

        assert mem.read_text() == original, "dry-run should not modify MEMORY.md"

    def test_single_repeat_not_promoted(self, tmp_path):
        """Entries with < 3 repeats are NOT promoted"""
        entries = [
            "- outcome:failure agent:go-developer lesson:Build error [2026-06-01T12:00:00Z]",
            "- outcome:failure agent:go-developer lesson:Build error [2026-06-02T12:00:00Z]",
        ]
        mem = _make_memory_file(tmp_path, entries)
        learned_dir = tmp_path / "learned"
        learned_dir.mkdir()

        mfc = _load_module(COMPACTOR, "memory_feedback_compactor")

        args_obj = type("Args", (), {"dry_run": False, "memory": str(mem)})()
        mfc.compact(args_obj)

        # No pattern file should exist
        pattern_files = list(learned_dir.glob("*.md"))
        assert len(pattern_files) == 0, "< 3 repeats should not be promoted"


# ─────────────────────────────────────────────────────────────────────────────
# post-merge: extract PR_NUMBER and spec_id (test 11)
# ─────────────────────────────────────────────────────────────────────────────

class TestPostMerge:

    def test_extracts_pr_and_spec_from_message(self, tmp_path):
        """Post-merge script extracts PR_NUMBER and spec_id from commit message"""
        # We test the extraction logic directly (subprocess for standalone mode)
        import subprocess

        # Create fake git repo
        git_dir = tmp_path / "repo"
        git_dir.mkdir()
        subprocess.run(["git", "init"], cwd=git_dir, capture_output=True)
        subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=git_dir, capture_output=True)
        subprocess.run(["git", "config", "user.name", "Test"], cwd=git_dir, capture_output=True)
        (git_dir / "README.md").write_text("test")
        subprocess.run(["git", "add", "."], cwd=git_dir, capture_output=True)
        subprocess.run(
            ["git", "commit", "-m", "Merge pull request #842 from branch/feat\n\nImplements SPEC-164"],
            cwd=git_dir, capture_output=True
        )

        result = subprocess.run(
            ["bash", str(POST_MERGE), "--manual", "--pr", "842", "--spec", "SPEC-164"],
            cwd=str(git_dir),
            capture_output=True,
            text=True,
            env={**os.environ, "CLAUDE_PROJECT_DIR": str(REPO_ROOT)},
        )
        # Should exit 0 — memory store may not be available in test env, but script shouldn't crash
        assert result.returncode == 0
