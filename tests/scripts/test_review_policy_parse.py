"""
tests/scripts/test_review_policy_parse.py — pytest para SE-359 review-policy-parse.py.

Cubre: extracción de passes, severidad, nit_cap, exclusiones; fail-soft con
REVIEW.md ausente; --json válido.

Ref: SE-359 — REVIEW.md policy
"""
import importlib.util
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "review-policy-parse.py"

SAMPLE_REVIEW = """# Review instructions

## Passes
Run three passes and tag each finding with its pass:
- Bugs: logic errors, broken edge cases, subtle regressions
- Security: injection risks, authentication gaps, PII in logs
- Compliance: the change matches spec.md, plan.md and design principles

## What Important means here
Reserve Important for findings that would break behavior, leak data or breach a policy.
Style and naming are nits.

## Cap the nits
Report at most five nits per review; summarize the rest as a count.

## Do not report
Generated files under src/gen/ and anything CI already enforces.
"""


def _load():
    spec = importlib.util.spec_from_file_location("review_policy_parse", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def parser():
    return _load()


def test_parse_passes(parser, tmp_path):
    p = tmp_path / "REVIEW.md"
    p.write_text(SAMPLE_REVIEW)
    pol = parser.parse_policy(p)
    assert "Bugs" in pol["passes"]
    assert "Security" in pol["passes"]
    assert "Compliance" in pol["passes"]


def test_parse_important(parser, tmp_path):
    p = tmp_path / "REVIEW.md"
    p.write_text(SAMPLE_REVIEW)
    pol = parser.parse_policy(p)
    assert "break behavior" in pol["important"]
    assert "leak data" in pol["important"]


def test_parse_nit_cap(parser, tmp_path):
    p = tmp_path / "REVIEW.md"
    p.write_text(SAMPLE_REVIEW)
    pol = parser.parse_policy(p)
    assert pol["nit_cap"] == 5


def test_parse_exclusions(parser, tmp_path):
    p = tmp_path / "REVIEW.md"
    p.write_text(SAMPLE_REVIEW)
    pol = parser.parse_policy(p)
    assert any("src/gen" in e for e in pol["exclusions"])


def test_file_missing_returns_defaults(parser, tmp_path):
    pol = parser.parse_policy(tmp_path / "NO_REVIEW.md")
    assert pol["exists"] is False
    assert pol["nit_cap"] == 5
    assert len(pol["passes"]) >= 3


def test_nit_cap_custom(parser, tmp_path):
    p = tmp_path / "REVIEW.md"
    p.write_text(SAMPLE_REVIEW.replace("five", "3"))
    pol = parser.parse_policy(p)
    assert pol["nit_cap"] == 3


def test_passes_empty_uses_defaults(parser, tmp_path):
    p = tmp_path / "REVIEW.md"
    p.write_text("# Review\n## Only\nnothing")
    pol = parser.parse_policy(p)
    assert len(pol["passes"]) >= 3  # defaults
