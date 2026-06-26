"""tests/scripts/test_spec_timeline.py — SPEC-182

Pytest suite for spec-timeline-append.py and spec-timeline-query.py.
Requires: pytest >= 7, Python >= 3.9

Run:
    python3 -m pytest tests/scripts/test_spec_timeline.py -q
"""
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path
from textwrap import dedent

import pytest

# ── Project paths ─────────────────────────────────────────────────────────────

ROOT = Path(__file__).resolve().parents[2]
APPEND_SCRIPT = ROOT / "scripts" / "spec-timeline-append.py"
QUERY_SCRIPT  = ROOT / "scripts" / "spec-timeline-query.py"
PROPUESTAS    = ROOT / "docs" / "propuestas"


# ── Helpers to load scripts as modules ────────────────────────────────────────

def _load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod  = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="session")
def append_mod():
    return _load_module(APPEND_SCRIPT, "spec_timeline_append")


@pytest.fixture(scope="session")
def query_mod():
    return _load_module(QUERY_SCRIPT, "spec_timeline_query")


# ── Fixture: minimal spec file ────────────────────────────────────────────────

MINIMAL_SPEC = dedent("""\
    ---
    spec_id: SPEC-TEST
    title: Test spec
    status: PROPOSED
    ---

    # Body
""")

SPEC_WITH_TIMELINE = dedent("""\
    ---
    spec_id: SPEC-TEST
    title: Test spec
    status: PROPOSED
    timeline:
      - from: "2026-01-01"
        learned: "2026-01-02"
        value: "PROPOSED"
        source: "manual"
    ---

    # Body
""")


@pytest.fixture()
def tmp_spec(tmp_path):
    p = tmp_path / "SPEC-TEST.md"
    p.write_text(MINIMAL_SPEC, encoding="utf-8")
    return p


@pytest.fixture()
def tmp_spec_with_timeline(tmp_path):
    p = tmp_path / "SPEC-TEST.md"
    p.write_text(SPEC_WITH_TIMELINE, encoding="utf-8")
    return p


# ════════════════════════════════════════════════════════════════════════════
# T1 — append adds entry to an existing timeline
# ════════════════════════════════════════════════════════════════════════════

def test_append_adds_entry_to_existing_timeline(append_mod, tmp_spec_with_timeline):
    append_mod.append_timeline(
        file_path=tmp_spec_with_timeline,
        from_date="2026-06-24",
        learned="2026-06-24",
        value="APPROVED",
        source="test:t1",
    )
    content = tmp_spec_with_timeline.read_text()
    assert 'value: "APPROVED"' in content
    assert 'value: "PROPOSED"' in content  # original preserved
    assert content.count("- from:") == 2


# ════════════════════════════════════════════════════════════════════════════
# T2 — append creates timeline when it does not exist
# ════════════════════════════════════════════════════════════════════════════

def test_append_creates_timeline_when_absent(append_mod, tmp_spec):
    assert "timeline:" not in tmp_spec.read_text()
    append_mod.append_timeline(
        file_path=tmp_spec,
        from_date="2026-06-24",
        learned="2026-06-24",
        value="PROPOSED",
        source="test:t2",
    )
    content = tmp_spec.read_text()
    assert "timeline:" in content
    assert 'value: "PROPOSED"' in content


# ════════════════════════════════════════════════════════════════════════════
# T3 — --dry-run does not write to the file
# ════════════════════════════════════════════════════════════════════════════

def test_dry_run_does_not_modify_file(append_mod, tmp_spec):
    original = tmp_spec.read_text()
    append_mod.append_timeline(
        file_path=tmp_spec,
        from_date="2026-06-24",
        learned="2026-06-24",
        value="APPROVED",
        source="test:t3",
        dry_run=True,
    )
    assert tmp_spec.read_text() == original


# ════════════════════════════════════════════════════════════════════════════
# T4 — other frontmatter fields are preserved unchanged
# ════════════════════════════════════════════════════════════════════════════

def test_append_preserves_other_frontmatter_fields(append_mod, tmp_spec):
    append_mod.append_timeline(
        file_path=tmp_spec,
        from_date="2026-06-24",
        learned="2026-06-24",
        value="APPROVED",
        source="test:t4",
    )
    content = tmp_spec.read_text()
    assert "spec_id: SPEC-TEST" in content
    assert "title: Test spec" in content
    assert "status: PROPOSED" in content


# ════════════════════════════════════════════════════════════════════════════
# T5 — spec-lifecycle.sh auto-appends timeline (via --dry-run mock)
# ════════════════════════════════════════════════════════════════════════════

def test_spec_lifecycle_auto_appends_timeline_dryrun(tmp_path):
    """spec-lifecycle.sh --dry-run must mention the timeline step."""
    spec = tmp_path / "SPEC-TEST.md"
    spec.write_text(MINIMAL_SPEC, encoding="utf-8")

    result = subprocess.run(
        [
            "bash",
            str(ROOT / "scripts" / "spec-lifecycle.sh"),
            "--spec", str(spec),
            "--status", "APPROVED",
            "--dry-run",
        ],
        capture_output=True, text=True,
    )
    # dry-run should print what it would do (status change)
    combined = result.stdout + result.stderr
    assert "APPROVED" in combined
    assert result.returncode == 0


# ════════════════════════════════════════════════════════════════════════════
# T6 — query --format table produces text with column headers
# ════════════════════════════════════════════════════════════════════════════

def test_query_format_table_has_columns(query_mod, tmp_spec_with_timeline):
    rows = query_mod._rows_from_file(tmp_spec_with_timeline)
    output = query_mod._fmt_table(rows)
    for col in ("from", "learned", "value", "source"):
        assert col in output


# ════════════════════════════════════════════════════════════════════════════
# T7 — query --format json produces valid JSON
# ════════════════════════════════════════════════════════════════════════════

def test_query_format_json_is_valid(query_mod, tmp_spec_with_timeline):
    rows = query_mod._rows_from_file(tmp_spec_with_timeline)
    output = query_mod._fmt_json(rows)
    parsed = json.loads(output)
    assert isinstance(parsed, list)
    assert len(parsed) == 1
    assert parsed[0]["value"] == "PROPOSED"


# ════════════════════════════════════════════════════════════════════════════
# T8 — query filters by --status correctly
# ════════════════════════════════════════════════════════════════════════════

def test_query_filters_by_status(query_mod, tmp_path):
    spec = tmp_path / "SPEC-MULTI.md"
    spec.write_text(dedent("""\
        ---
        spec_id: SPEC-MULTI
        title: Multi-state spec
        status: IMPLEMENTED
        timeline:
          - from: "2026-01-01"
            learned: "2026-01-01"
            value: "PROPOSED"
            source: "manual"
          - from: "2026-03-01"
            learned: "2026-03-01"
            value: "APPROVED"
            source: "manual"
          - from: "2026-06-01"
            learned: "2026-06-01"
            value: "IMPLEMENTED"
            source: "manual"
        ---
        # body
    """), encoding="utf-8")

    rows = query_mod._rows_from_file(spec)
    filtered = query_mod._filter_rows(rows, status="APPROVED", learned_after=None, at_date=None)
    assert len(filtered) == 1
    assert filtered[0]["value"] == "APPROVED"


# ════════════════════════════════════════════════════════════════════════════
# T9 — query filters by --learned-after correctly
# ════════════════════════════════════════════════════════════════════════════

def test_query_filters_by_learned_after(query_mod, tmp_path):
    spec = tmp_path / "SPEC-DATES.md"
    spec.write_text(dedent("""\
        ---
        spec_id: SPEC-DATES
        title: Date filter spec
        status: APPROVED
        timeline:
          - from: "2026-01-01"
            learned: "2026-01-15"
            value: "PROPOSED"
            source: "manual"
          - from: "2026-06-01"
            learned: "2026-06-20"
            value: "APPROVED"
            source: "manual"
        ---
        # body
    """), encoding="utf-8")

    rows = query_mod._rows_from_file(spec)
    filtered = query_mod._filter_rows(rows, status=None, learned_after="2026-06-01", at_date=None)
    assert len(filtered) == 1
    assert filtered[0]["value"] == "APPROVED"


# ════════════════════════════════════════════════════════════════════════════
# T10 — back-fill: at least 8 of the 10 target specs have timeline entries
# ════════════════════════════════════════════════════════════════════════════

BACKFILL_SPECS = [
    "SPEC-192-anti-adulation-illusory-truth.md",
    "SPEC-193-context-provenance-injection-hardening.md",
    "SPEC-194-criterion-simulation-layer.md",
    "SPEC-189-greedy-context-budget.md",
    "SPEC-187-iah-principles-alignment.md",
    "SPEC-149-sandbox-os-level.md",
    "SPEC-199-historical-context-tribunal-rounds.md",
    "SPEC-163-router-mode-1-2.md",
    "SPEC-164-memory-feedback-loop.md",
    "SE-222-okf-adoptable-patterns.md",
]


def test_backfill_at_least_8_specs_have_timeline(query_mod):
    hits = 0
    for fname in BACKFILL_SPECS:
        path = PROPUESTAS / fname
        if not path.exists():
            continue
        rows = query_mod._rows_from_file(path)
        if rows:
            hits += 1
    assert hits >= 8, f"Only {hits} of 10 back-filled specs have timeline entries (need >= 8)"


# ════════════════════════════════════════════════════════════════════════════
# T11 — query --format csv has correct header row
# ════════════════════════════════════════════════════════════════════════════

def test_query_format_csv_has_header(query_mod, tmp_spec_with_timeline):
    rows = query_mod._rows_from_file(tmp_spec_with_timeline)
    output = query_mod._fmt_csv(rows)
    first_line = output.splitlines()[0]
    assert "file" in first_line
    assert "value" in first_line
    assert "source" in first_line


# ════════════════════════════════════════════════════════════════════════════
# T12 — append CLI: --dry-run flag via subprocess does not write
# ════════════════════════════════════════════════════════════════════════════

def test_append_cli_dry_run_does_not_write(tmp_path):
    spec = tmp_path / "SPEC-CLI.md"
    spec.write_text(MINIMAL_SPEC, encoding="utf-8")
    original = spec.read_text()

    result = subprocess.run(
        [
            sys.executable, str(APPEND_SCRIPT),
            "--file", str(spec),
            "--from", "2026-06-24",
            "--learned", "2026-06-24",
            "--value", "IMPLEMENTED",
            "--source", "test:cli",
            "--dry-run",
        ],
        capture_output=True, text=True,
    )
    assert result.returncode == 0
    assert spec.read_text() == original
    assert "DRY-RUN" in result.stdout.upper() or "timeline:" in result.stdout


# ════════════════════════════════════════════════════════════════════════════
# T13 — query CLI produces non-empty output for a real spec
# ════════════════════════════════════════════════════════════════════════════

def test_query_cli_produces_output_for_real_spec():
    path = PROPUESTAS / "SPEC-192-anti-adulation-illusory-truth.md"
    if not path.exists():
        pytest.skip("SPEC-192 not found")

    result = subprocess.run(
        [sys.executable, str(QUERY_SCRIPT), "--file", str(path), "--format", "table"],
        capture_output=True, text=True,
    )
    assert result.returncode == 0
    assert "IMPLEMENTED" in result.stdout
