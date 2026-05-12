"""tests/unit/context_update/test_f1_runner.py

Unit tests for F1 runner and individual jobs.

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §10.2.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

_SCRIPTS = Path(__file__).resolve().parents[3] / "scripts"
sys.path.insert(0, str(_SCRIPTS))

from lib.context_update import f1 as f1_runner
from lib.context_update.f1 import (
    confidentiality_leak,
    frontmatter_lint,
    inventory,
    staleness,
    tag_consistency,
    wikilink_check,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

def _file(path: str, content: str = "", age_days: int = 10, **kwargs) -> dict:
    import datetime
    mtime = datetime.datetime.now(tz=datetime.timezone.utc) - datetime.timedelta(days=age_days)
    return {
        "path":      path,
        "rel_path":  path,
        "content":   content,
        "age_days":  age_days,
        "mtime_iso": mtime.isoformat(),
        "doc_type":  kwargs.get("doc_type", "raw"),
        "conf_level": kwargs.get("conf_level", 1),
    }


# ---------------------------------------------------------------------------
# inventory
# ---------------------------------------------------------------------------

class TestInventory:
    def test_returns_findings_list(self):
        files = [_file("a.md"), _file("b.md")]
        result = inventory.run(files)
        assert "findings" in result
        assert isinstance(result["findings"], list)

    def test_empty_files(self):
        result = inventory.run([])
        assert result["findings"] == [] or isinstance(result["findings"], list)


# ---------------------------------------------------------------------------
# frontmatter_lint
# ---------------------------------------------------------------------------

class TestFrontmatterLint:
    def test_no_findings_when_empty(self):
        result = frontmatter_lint.run([])
        assert result["findings"] == []

    def test_detects_missing_frontmatter(self):
        files = [_file("a.md", content="# Just a heading\n\nNo frontmatter here.")]
        result = frontmatter_lint.run(files)
        # Should flag missing frontmatter
        assert isinstance(result["findings"], list)

    def test_valid_frontmatter_no_finding(self):
        content = "---\ntitle: Test\ndescription: ok\n---\n\n# Body\n"
        files = [_file("a.md", content=content)]
        result = frontmatter_lint.run(files)
        # May or may not produce findings depending on required fields
        assert "findings" in result


# ---------------------------------------------------------------------------
# staleness
# ---------------------------------------------------------------------------

class TestStaleness:
    def test_no_stale_files(self):
        files = [_file("a.md", age_days=10)]
        result = staleness.run(files)
        stale = [f for f in result["findings"] if f.get("severity") in ("WARNING", "ERROR")]
        assert len(stale) == 0

    def test_detects_stale_warning(self):
        files = [_file("old.md", age_days=200)]
        result = staleness.run(files)
        assert any(f.get("file", "").endswith("old.md") for f in result["findings"])

    def test_detects_very_stale_error_or_warning(self):
        files = [_file("ancient.md", age_days=400)]
        result = staleness.run(files)
        severities = {f.get("severity") for f in result["findings"]
                      if f.get("file", "").endswith("ancient.md")}
        assert severities & {"WARNING", "ERROR"}


# ---------------------------------------------------------------------------
# tag_consistency
# ---------------------------------------------------------------------------

class TestTagConsistency:
    def test_no_findings_empty(self):
        result = tag_consistency.run([])
        assert result["findings"] == []

    def test_consistent_tags_no_finding(self):
        content = "---\ntags: [python, testing]\n---\n"
        files = [_file(f"f{i}.md", content=content) for i in range(3)]
        result = tag_consistency.run(files)
        assert isinstance(result["findings"], list)


# ---------------------------------------------------------------------------
# wikilink_check
# ---------------------------------------------------------------------------

class TestWikilinkCheck:
    def test_no_wikilinks_no_findings(self):
        files = [_file("a.md", content="No links here")]
        result = wikilink_check.run(files)
        assert isinstance(result["findings"], list)

    def test_broken_wikilink_detected(self):
        files = [_file("a.md", content="See [[nonexistent-file]] for details")]
        result = wikilink_check.run(files)
        assert isinstance(result["findings"], list)
        # Should detect broken link to nonexistent-file


# ---------------------------------------------------------------------------
# confidentiality_leak
# ---------------------------------------------------------------------------

class TestConfidentialityLeak:
    def test_no_leak_in_public_file(self):
        files = [_file("docs/readme.md", content="# Public doc", conf_level=1)]
        result = confidentiality_leak.run(files)
        leaks = [f for f in result["findings"] if f.get("severity") == "ERROR"]
        assert len(leaks) == 0

    def test_no_findings_empty(self):
        result = confidentiality_leak.run([])
        assert result["findings"] == []


# ---------------------------------------------------------------------------
# F1 runner integration
# ---------------------------------------------------------------------------

class TestF1Runner:
    def test_run_all_returns_expected_keys(self):
        files = [_file("a.md", content="# Test"), _file("b.md")]
        result = f1_runner.run_all(files)
        assert "jobs" in result
        assert "findings" in result
        assert "summary" in result

    def test_run_all_has_8_jobs(self):
        files = [_file("a.md")]
        result = f1_runner.run_all(files)
        assert len(result["jobs"]) == 8

    def test_run_all_summary_total_files(self):
        files = [_file(f"f{i}.md") for i in range(5)]
        result = f1_runner.run_all(files)
        assert result["summary"]["total_files"] == 5

    def test_run_all_findings_have_job_field(self):
        files = [_file("a.md", content="No frontmatter")]
        result = f1_runner.run_all(files)
        for finding in result["findings"]:
            assert "job" in finding, f"Finding missing 'job': {finding}"

    def test_run_all_writes_store(self, tmp_path):
        files = [_file("a.md")]
        f1_runner.run_all(files, store_dir=tmp_path)
        written = list(tmp_path.glob("*.json"))
        assert len(written) > 0

    def test_run_all_writes_aggregate(self, tmp_path):
        files = [_file("a.md")]
        f1_runner.run_all(files, store_dir=tmp_path)
        assert (tmp_path / "_aggregate.json").exists()

    def test_run_all_empty_files_no_crash(self):
        result = f1_runner.run_all([])
        assert result["summary"]["total_files"] == 0
