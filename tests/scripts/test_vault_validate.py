"""
Tests for scripts/vault-validate.py — SPEC-PROJECT-UPDATE Fase 1, AC-1.5.

>=12 cases: 1 valid + 1 invalid per entity_type, plus leak / slug-mismatch /
parser corner cases. Pure-function tests (no I/O).
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "vault-validate.py"

_spec = importlib.util.spec_from_file_location("vault_validate", SCRIPT)
vv = importlib.util.module_from_spec(_spec)
sys.modules["vault_validate"] = vv
_spec.loader.exec_module(vv)


# ──────────────────────────────────────────────────────────────────────────────
# Helpers — minimal valid frontmatter generators per entity_type
# ──────────────────────────────────────────────────────────────────────────────

COMMON = {
    "confidentiality": "N4",
    "project": "aurora",
    "title": "X",
    "created": "2026-05-07T10:00:00+02:00",
    "updated": "2026-05-07T10:00:00+02:00",
}

VALID_BY_TYPE: dict[str, dict] = {
    "pbi": {**COMMON, "entity_type": "pbi", "pbi_id": "AB#1234", "state": "Active"},
    "decision": {
        **COMMON, "entity_type": "decision",
        "decision_id": "DEC-aurora-001",
        "decided_at": "2026-05-07",
    },
    "meeting": {
        **COMMON, "entity_type": "meeting",
        "meeting_id": "MTG-001", "meeting_date": "2026-05-07",
        "attendees": ["alice", "bob"],
        "transcript_source": "teams.vtt",
        "digest_status": "pending",
    },
    "person": {**COMMON, "entity_type": "person", "role": "PM"},
    "risk": {
        **COMMON, "entity_type": "risk",
        "risk_id": "RISK-001", "severity": "high",
        "status": "open", "owner": "alice",
    },
    "spec": {
        **COMMON, "entity_type": "spec",
        "spec_id": "SPEC-XYZ", "status": "approved",
    },
    "session": {
        **COMMON, "entity_type": "session",
        "session_date": "2026-05-07T10:00:00+02:00",
        "frontend": "claude-code",
    },
    "digest": {
        **COMMON, "entity_type": "digest",
        "source": "meeting", "source_id": "MTG-001",
        "digested_at": "2026-05-07T10:00:00+02:00",
        "digest_agent": "meeting-digest",
    },
    "moc": {**COMMON, "entity_type": "moc"},
    "inbox": {**COMMON, "entity_type": "inbox"},
}


def _to_yaml(d: dict) -> str:
    """Render a flat dict back to YAML-subset frontmatter text."""
    lines = ["---"]
    for k, v in d.items():
        if isinstance(v, list):
            lines.append(f"{k}: [{', '.join(str(x) for x in v)}]")
        elif isinstance(v, str):
            if any(c in v for c in (":", "#", '"')):
                lines.append(f'{k}: "{v}"')
            else:
                lines.append(f"{k}: {v}")
        elif v is None:
            lines.append(f"{k}: ~")
        else:
            lines.append(f"{k}: {v}")
    lines.append("---")
    lines.append("")
    lines.append("body")
    return "\n".join(lines)


# ──────────────────────────────────────────────────────────────────────────────
# Tests — valid case per entity_type (10 tests)
# ──────────────────────────────────────────────────────────────────────────────

@pytest.mark.parametrize("entity_type", sorted(VALID_BY_TYPE.keys()))
def test_valid_per_entity_type(entity_type):
    fm = vv.parse_frontmatter(_to_yaml(VALID_BY_TYPE[entity_type]))
    errs = vv.validate_frontmatter(fm, expected_slug="aurora", expected_path_n_level="N4")
    assert errs == [], f"valid {entity_type} produced errors: {errs}"


# ──────────────────────────────────────────────────────────────────────────────
# Tests — invalid case per entity_type (10 tests)
# Drop a required-per-entity field and assert an error mentioning it.
# ──────────────────────────────────────────────────────────────────────────────

INVALID_DROP = {
    "pbi": "pbi_id",
    "decision": "decision_id",
    "meeting": "meeting_id",
    "person": "role",
    "risk": "risk_id",
    "spec": "spec_id",
    "session": "session_date",
    "digest": "source",
}


@pytest.mark.parametrize("entity_type,field", list(INVALID_DROP.items()))
def test_invalid_missing_field_per_entity_type(entity_type, field):
    bad = dict(VALID_BY_TYPE[entity_type])
    del bad[field]
    fm = vv.parse_frontmatter(_to_yaml(bad))
    errs = vv.validate_frontmatter(fm, expected_slug="aurora", expected_path_n_level="N4")
    assert errs, f"expected errors for missing `{field}` in {entity_type}"
    assert any(field in e for e in errs), f"errors do not mention `{field}`: {errs}"


# ──────────────────────────────────────────────────────────────────────────────
# Cross-cutting checks
# ──────────────────────────────────────────────────────────────────────────────

def test_no_frontmatter_at_all():
    text = "no frontmatter here\n"
    fm = vv.parse_frontmatter(text)
    assert fm is None
    errs = vv.validate_frontmatter(fm)
    assert errs == ["frontmatter missing or malformed (no `---` block found)"]


def test_unterminated_frontmatter():
    text = "---\nconfidentiality: N1\n# no closing\n"
    assert vv.parse_frontmatter(text) is None


def test_invalid_confidentiality_value():
    bad = dict(VALID_BY_TYPE["pbi"]); bad["confidentiality"] = "N9"
    errs = vv.validate_frontmatter(vv.parse_frontmatter(_to_yaml(bad)))
    assert any("confidentiality" in e for e in errs)


def test_invalid_entity_type_value():
    bad = dict(VALID_BY_TYPE["pbi"]); bad["entity_type"] = "not-a-type"
    errs = vv.validate_frontmatter(vv.parse_frontmatter(_to_yaml(bad)))
    assert any("entity_type" in e for e in errs)


def test_slug_mismatch():
    fm = vv.parse_frontmatter(_to_yaml(VALID_BY_TYPE["pbi"]))
    errs = vv.validate_frontmatter(fm, expected_slug="beacon")
    assert any("project" in e and "mismatch" in e for e in errs)


def test_n4_to_n1_path_blocks():
    """AC-1.4: confidentiality:N4 in non-N4 path must produce an error."""
    fm = vv.parse_frontmatter(_to_yaml(VALID_BY_TYPE["pbi"]))
    errs = vv.validate_frontmatter(fm, expected_slug="aurora", expected_path_n_level="N1")
    assert any("leak" in e.lower() or "cannot be written" in e for e in errs)


def test_n1_to_n1_path_ok():
    ok = dict(VALID_BY_TYPE["spec"]); ok["confidentiality"] = "N1"
    fm = vv.parse_frontmatter(_to_yaml(ok))
    errs = vv.validate_frontmatter(fm, expected_slug="aurora", expected_path_n_level="N1")
    assert errs == []


def test_invalid_iso_date():
    bad = dict(VALID_BY_TYPE["meeting"]); bad["meeting_date"] = "not-a-date"
    errs = vv.validate_frontmatter(vv.parse_frontmatter(_to_yaml(bad)))
    assert any("meeting_date" in e for e in errs)


def test_invalid_risk_severity():
    bad = dict(VALID_BY_TYPE["risk"]); bad["severity"] = "ULTRA"
    errs = vv.validate_frontmatter(vv.parse_frontmatter(_to_yaml(bad)))
    assert any("severity" in e for e in errs)


def test_invalid_session_frontend():
    bad = dict(VALID_BY_TYPE["session"]); bad["frontend"] = "vim"
    errs = vv.validate_frontmatter(vv.parse_frontmatter(_to_yaml(bad)))
    assert any("frontend" in e for e in errs)


def test_path_inference():
    assert vv.infer_path_n_level("projects/aurora_main/x/vault/foo.md") == "N4"
    assert vv.infer_path_n_level("tenants/acme/notes/foo.md") == "N4"
    assert vv.infer_path_n_level("/home/u/.savia/foo.md") == "N3"
    assert vv.infer_path_n_level("output/report.md") == "N2"
    assert vv.infer_path_n_level("docs/specs/foo.md") == "N1"
    assert vv.infer_path_n_level("config.local.json") == "N2"


def test_slug_inference():
    assert vv.infer_slug_from_path("projects/aurora_main/aurora-monica/vault/x.md") == "aurora"
    assert vv.infer_slug_from_path("tenants/acme/foo.md") == "acme"
    assert vv.infer_slug_from_path("docs/specs/SPEC-X.md") is None
    # Windows-style path
    assert vv.infer_slug_from_path("projects\\beacon_main\\beacon-bob\\vault\\x.md") == "beacon"


def test_inline_list_with_quoted_comma():
    text = '---\nconfidentiality: N1\nproject: aurora\nentity_type: moc\ntitle: x\ncreated: 2026-05-07\nupdated: 2026-05-07\ntags: [a, "b, c", d]\n---\n'
    fm = vv.parse_frontmatter(text)
    assert fm["tags"] == ["a", "b, c", "d"]


def test_block_list_attendees():
    text = (
        "---\n"
        "confidentiality: N4\n"
        "project: aurora\n"
        "entity_type: meeting\n"
        "title: x\n"
        "created: 2026-05-07\n"
        "updated: 2026-05-07\n"
        "meeting_id: M1\n"
        "meeting_date: 2026-05-07\n"
        "attendees:\n"
        "  - alice\n"
        "  - bob\n"
        "transcript_source: x.vtt\n"
        "digest_status: done\n"
        "---\n"
    )
    fm = vv.parse_frontmatter(text)
    assert fm["attendees"] == ["alice", "bob"]
    errs = vv.validate_frontmatter(fm, expected_slug="aurora", expected_path_n_level="N4")
    assert errs == []
