"""tests/unit/context_update/test_f3_consolidator.py

Unit tests for F3 consolidator: composite_quality, block assignment,
plan structure, and canonical artefact names.

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §10.2 AC-30.
"""
from __future__ import annotations

import json
import tempfile
from pathlib import Path

import pytest

import sys
_SCRIPTS = Path(__file__).resolve().parents[3] / "scripts"
sys.path.insert(0, str(_SCRIPTS))

from lib.context_update import f3 as f3_consolidator
from lib.context_update.f3 import (
    _assign_block,
    _compute_composite_quality,
    _compute_coverage_frontmatter,
    _compute_confidentiality_integrity,
    _BLOCK_CRITICAL,
    _BLOCK_IMPORTANT,
    _BLOCK_MAINTENANCE,
    _BLOCK_QUALITY,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

def _finding(job: str, severity: str, file: str = "a.md", **kwargs) -> dict:
    return {"job": job, "severity": severity, "file": file, **kwargs}


def _f1_result(findings: list[dict], total_files: int = 10) -> dict:
    return {
        "findings": findings,
        "summary": {"total_files": total_files},
        "jobs": {
            f.get("job", "x"): {"findings": [f]}
            for f in findings
        },
    }


def _f2_result(findings: list[dict]) -> dict:
    return {"findings": findings, "summary": {"total_files": 0}}


# ---------------------------------------------------------------------------
# composite_quality tests
# ---------------------------------------------------------------------------

class TestCompositeQuality:
    def test_perfect_score_no_findings(self):
        r = _compute_composite_quality([])
        assert r["composite_quality"] == 1.0
        assert r["composite_quality_grade"] == "A"

    def test_errors_reduce_score(self):
        findings = [_finding("secret_scan", "ERROR")] * 4
        r = _compute_composite_quality(findings)
        assert r["composite_quality"] == pytest.approx(0.80, abs=0.01)
        assert r["composite_quality_grade"] == "B+"

    def test_error_cap_at_040(self):
        findings = [_finding("secret_scan", "ERROR")] * 20
        r = _compute_composite_quality(findings)
        # max deduction from errors = 0.40 → score ≥ 0.60
        assert r["composite_quality"] >= 0.60 - 0.01

    def test_warnings_reduce_score(self):
        findings = [_finding("frontmatter_lint", "WARNING")] * 10
        r = _compute_composite_quality(findings)
        assert r["composite_quality"] == pytest.approx(0.80, abs=0.01)

    def test_floor_at_zero(self):
        findings = (
            [_finding("secret_scan", "ERROR")] * 20
            + [_finding("frontmatter_lint", "WARNING")] * 20
            + [_finding("tag_consistency", "INFO")] * 20
        )
        r = _compute_composite_quality(findings)
        assert r["composite_quality"] >= 0.0

    def test_grade_d_below_060(self):
        findings = [_finding("secret_scan", "ERROR")] * 10 + \
                   [_finding("frontmatter_lint", "WARNING")] * 15
        r = _compute_composite_quality(findings)
        assert r["composite_quality_grade"] == "D"

    def test_trend_positive(self):
        r = _compute_composite_quality([], previous=0.70)
        assert r["trend"] == "+0.3"

    def test_trend_negative(self):
        findings = [_finding("secret_scan", "ERROR")] * 4
        r = _compute_composite_quality(findings, previous=1.0)
        assert r["trend"].startswith("-")

    def test_no_trend_when_no_previous(self):
        r = _compute_composite_quality([])
        assert r["trend"] is None


# ---------------------------------------------------------------------------
# Block assignment tests
# ---------------------------------------------------------------------------

class TestBlockAssignment:
    def test_error_always_critical(self):
        f = _finding("tag_consistency", "ERROR")
        assert _assign_block(f) == _BLOCK_CRITICAL

    def test_secret_scan_critical(self):
        f = _finding("secret_scan", "WARNING")
        assert _assign_block(f) == _BLOCK_CRITICAL

    def test_confidentiality_leak_critical(self):
        f = _finding("confidentiality_leak", "WARNING")
        assert _assign_block(f) == _BLOCK_CRITICAL

    def test_frontmatter_important(self):
        f = _finding("frontmatter_lint", "WARNING")
        assert _assign_block(f) == _BLOCK_IMPORTANT

    def test_wikilink_important(self):
        f = _finding("wikilink_check", "WARNING")
        assert _assign_block(f) == _BLOCK_IMPORTANT

    def test_staleness_maintenance(self):
        f = _finding("staleness", "INFO")
        assert _assign_block(f) == _BLOCK_MAINTENANCE

    def test_duplicate_maintenance(self):
        f = _finding("duplicate_detection", "WARNING")
        assert _assign_block(f) == _BLOCK_MAINTENANCE

    def test_quality_judge_quality(self):
        f = _finding("context_quality_judge", "INFO")
        assert _assign_block(f) == _BLOCK_QUALITY

    def test_tag_consistency_quality(self):
        f = _finding("tag_consistency", "INFO")
        assert _assign_block(f) == _BLOCK_QUALITY

    def test_unknown_warning_defaults_important(self):
        f = _finding("unknown_job", "WARNING")
        assert _assign_block(f) == _BLOCK_IMPORTANT

    def test_unknown_info_defaults_maintenance(self):
        f = _finding("unknown_job", "INFO")
        assert _assign_block(f) == _BLOCK_MAINTENANCE


# ---------------------------------------------------------------------------
# Coverage frontmatter tests
# ---------------------------------------------------------------------------

class TestCoverageFrontmatter:
    def test_full_coverage(self):
        f1 = _f1_result([], total_files=10)
        f1["jobs"] = {"frontmatter_lint": {"findings": []}}
        assert _compute_coverage_frontmatter(f1) == 1.0

    def test_partial_coverage(self):
        findings = [_finding("frontmatter_lint", "WARNING", f"file{i}.md") for i in range(3)]
        f1 = _f1_result([], total_files=10)
        f1["jobs"] = {"frontmatter_lint": {"findings": findings}}
        val = _compute_coverage_frontmatter(f1)
        assert val == pytest.approx(0.7, abs=0.01)

    def test_zero_total_files(self):
        f1 = _f1_result([], total_files=0)
        assert _compute_coverage_frontmatter(f1) == 1.0


# ---------------------------------------------------------------------------
# Confidentiality integrity tests
# ---------------------------------------------------------------------------

class TestConfidentialityIntegrity:
    def test_no_leaks(self):
        f1 = _f1_result([], total_files=10)
        f1["jobs"] = {"confidentiality_leak": {"findings": []}}
        assert _compute_confidentiality_integrity(f1) == 1.0

    def test_with_leaks(self):
        job_name = "confidential" + "ity_leak"
        findings = [_finding(job_name, "ERROR", f"f{i}.md") for i in range(2)]
        f1 = _f1_result([], total_files=10)
        f1["jobs"] = {job_name: {"findings": findings}}
        val = _compute_confidentiality_integrity(f1)
        assert val == pytest.approx(0.8, abs=0.01)


# ---------------------------------------------------------------------------
# Full consolidate() tests
# ---------------------------------------------------------------------------

class TestConsolidate:
    def _run(self, f1_findings=None, f2_findings=None, store_dir=None):
        f1 = _f1_result(f1_findings or [], total_files=5)
        f2 = _f2_result(f2_findings or [])
        return f3_consolidator.consolidate(f1, f2, run_id="test-001", store_dir=store_dir)

    def test_returns_required_keys(self):
        r = self._run()
        for key in ("run_id", "generated", "findings", "plan", "backlog", "metrics", "summary", "report_md"):
            assert key in r, f"Missing key: {key}"

    def test_plan_has_4_blocks(self):
        r = self._run([_finding("secret_scan", "ERROR")])
        for block in ("block_1_critical", "block_2_important", "block_3_maintenance", "block_4_quality"):
            assert block in r["plan"]

    def test_findings_tagged_with_phase(self):
        r = self._run(
            f1_findings=[_finding("secret_scan", "ERROR")],
            f2_findings=[_finding("context_quality_judge", "INFO")],
        )
        phases = {f["phase"] for f in r["findings"]}
        assert phases == {"F1", "F2"}

    def test_report_md_contains_grade(self):
        r = self._run()
        assert "composite_quality" in r["report_md"].lower() or "grade" in r["report_md"].lower()

    def test_canonical_artefacts_written(self):
        with tempfile.TemporaryDirectory() as tmp:
            store_dir = Path(tmp)
            self._run(store_dir=store_dir)
            assert (store_dir / "F3_plan.json").exists()
            assert (store_dir / "F3_plan.md").exists()
            assert (store_dir / "consolidated.json").exists()

    def test_f3_plan_json_valid(self):
        with tempfile.TemporaryDirectory() as tmp:
            store_dir = Path(tmp)
            self._run([_finding("frontmatter_lint", "WARNING")], store_dir=store_dir)
            data = json.loads((store_dir / "F3_plan.json").read_text())
            assert "metrics" in data
            assert "plan" in data
            assert "run_id" in data

    def test_backlog_when_more_than_30(self):
        # 35 distinct-file findings → should overflow to backlog
        findings = [_finding("tag_consistency", "INFO", f"file{i}.md") for i in range(35)]
        r = self._run(findings)
        assert len(r["backlog"]) > 0

    def test_plan_items_have_required_fields(self):
        r = self._run([_finding("secret_scan", "ERROR")])
        for block_data in r["plan"].values():
            for item in block_data.get("items", []):
                for field in ("id", "action", "command_hint", "auto_applicable", "file", "job"):
                    assert field in item, f"Item missing field '{field}': {item}"
