"""tests/scripts/test_reconciliation_resolver.py — SPEC-183

Tests for scripts/reconciliation-resolver.py: 3-bucket drift classifier.
"""
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
from pathlib import Path

import pytest

# ── Load module ───────────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "reconciliation-resolver.py"


def _load():
    spec = importlib.util.spec_from_file_location("reconciliation_resolver", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["reconciliation_resolver"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load()
classify_drift = mod.classify_drift
resolve = mod.resolve
main = mod.main


# ── Fixtures ──────────────────────────────────────────────────────────────────

def _item_evolution():
    return {
        "file_a": "docs/CHANGELOG.md",
        "file_b": "docs/rules/domain/pm-config.md",
        "value_a": "562 commands",
        "value_b": "580 commands",
        "date_a": "2026-04-01",
        "date_b": "2026-06-01",
        "description": "counter update in changelog entry",
    }


def _item_auto_resolve_newer_authoritative():
    return {
        "file_a": "docs/rules/domain/note.md",
        "file_b": "docs/propuestas/SPEC-183-reconciliation-3bucket.md",
        "value_a": "old approach",
        "value_b": "new approach",
        "date_a": "2026-01-01",
        "date_b": "2026-06-01",
        "description": "approach description differs",
    }


def _item_auto_resolve_stale_counter():
    return {
        "file_a": "docs/rules/something.md",
        "file_b": "CLAUDE.md",
        "value_a": "70 agents available",
        "value_b": "75 agents available",
        "date_a": "2026-03-01",
        "date_b": "2026-06-10",
        "description": "agent count discrepancy",
    }


def _item_conflict():
    return {
        "file_a": "docs/rules/domain/rule-a.md",
        "file_b": "docs/rules/domain/rule-b.md",
        "value_a": "always require approval",
        "value_b": "auto-approve if low-risk",
        "date_a": "2026-05-01",
        "date_b": "2026-05-10",
        "description": "contradictory approval policies",
    }


# ── Tests: bucket classification ─────────────────────────────────────────────

def test_evolution_bucket_from_changelog():
    """Item referencing a CHANGELOG file → evolution."""
    result = classify_drift([_item_evolution()])
    assert len(result["evolution"]) == 1
    assert result["auto"] == []
    assert result["conflicts"] == []


def test_auto_resolve_newer_and_more_authoritative():
    """Newer spec beats older note → auto-resolve."""
    result = classify_drift([_item_auto_resolve_newer_authoritative()])
    assert len(result["auto"]) == 1
    assert result["conflicts"] == []


def test_auto_resolve_stale_counter():
    """Integer counter in text triggers auto-resolve."""
    result = classify_drift([_item_auto_resolve_stale_counter()])
    # stale counter → auto-resolve
    assert len(result["auto"]) == 1


def test_conflict_doc_ambiguous_policies():
    """Contradictory policies with no clear winner → conflict-doc."""
    result = classify_drift([_item_conflict()])
    assert len(result["conflicts"]) == 1
    assert result["conflicts"][0]["bucket"] == "conflict-doc"
    assert "topic" in result["conflicts"][0]


def test_metrics_counts():
    """resolve() returns correct metrics counts."""
    items = [
        _item_evolution(),
        _item_auto_resolve_newer_authoritative(),
        _item_auto_resolve_stale_counter(),
        _item_conflict(),
    ]
    output = resolve(items, apply=False)
    m = output["metrics"]
    assert m["found"] == 4
    assert m["auto"] + m["evolution"] + m["conflict"] == 4


def test_conflict_doc_has_required_fields():
    """conflict-doc entries carry topic, file, conflict_doc path."""
    result = classify_drift([_item_conflict()])
    c = result["conflicts"][0]
    assert c["bucket"] == "conflict-doc"
    assert "topic" in c
    assert "conflict_doc" in c
    assert c["conflict_doc"].startswith("output/conflicts/")


def test_auto_resolve_entry_structure():
    """auto-resolve entries have file, old_value, new_value, action."""
    result = classify_drift([_item_auto_resolve_newer_authoritative()])
    a = result["auto"][0]
    assert "file" in a
    assert "new_value" in a
    assert "action" in a


def test_empty_input():
    """Empty list produces empty buckets and zero metrics."""
    output = resolve([], apply=False)
    assert output["auto"] == []
    assert output["evolution"] == []
    assert output["conflicts"] == []
    assert output["metrics"]["found"] == 0


def test_apply_creates_conflict_doc(tmp_path):
    """--apply creates conflict-doc file with required frontmatter."""
    workspace = tmp_path
    (workspace / "output" / "conflicts").mkdir(parents=True, exist_ok=True)
    output = resolve([_item_conflict()], apply=True, workspace=workspace)
    assert output["applied"] is not None
    # Find the created doc
    created = list((workspace / "output" / "conflicts").glob("*.md"))
    assert len(created) == 1
    text = created[0].read_text()
    assert "status: open" in text
    assert "detected_at:" in text
    assert "sources:" in text


def test_cli_json_input(tmp_path):
    """CLI reads JSON file and emits JSON output."""
    items = [_item_conflict(), _item_evolution()]
    input_file = tmp_path / "drift.json"
    input_file.write_text(json.dumps(items), encoding="utf-8")
    # Patch stdout capture
    import io, contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = main(["--input", str(input_file), "--workspace", str(tmp_path), "--quiet"])
    assert rc == 0
    parsed = json.loads(buf.getvalue())
    assert "auto" in parsed
    assert "evolution" in parsed
    assert "conflicts" in parsed


def test_cli_missing_input(tmp_path):
    """CLI exits 1 when input file is missing."""
    rc = main(["--input", str(tmp_path / "nonexistent.json"), "--quiet"])
    assert rc == 1
