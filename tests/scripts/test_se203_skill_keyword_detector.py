"""Tests for SE-203 — Keyword triggers para skills.

Covers:
- AC1: "quiero hacer tdd" -> ["tdd-vertical-slices"]
- AC2: 10 required skills have trigger.keywords in frontmatter
- AC3: skill-trigger-map.md exists and has table format
- AC4: detection is case-insensitive
- AC5: multi-match: "spec de seguridad" returns multiple skills
- AC6: --list shows all triggers in table format
- AC7: PreTurn hook registered in settings.json
"""
from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
DETECTOR_SH = ROOT / "scripts" / "skill-keyword-detector.sh"
SKILLS_DIR = ROOT / ".opencode" / "skills"
SETTINGS_JSON = ROOT / ".claude" / "settings.json"
TRIGGER_MAP = ROOT / "docs" / "rules" / "domain" / "skill-trigger-map.md"

REQUIRED_SKILLS = [
    "savia-memory",
    "tdd-vertical-slices",
    "spec-driven-development",
    "adversarial-security",
    "performance-audit",
    "knowledge-graph",
    "weekly-report",
    "caveman",
    "zoom-out",
    "grill-me",
]


def run_detector(*args, env=None):
    base_env = os.environ.copy()
    base_env["SAVIA_SKILLS_DIR"] = str(SKILLS_DIR)
    if env:
        base_env.update(env)
    return subprocess.run(
        ["bash", str(DETECTOR_SH), *args],
        capture_output=True, text=True, env=base_env,
    )


def test_tdd_keyword_matches_skill():
    """AC1: 'quiero hacer tdd' -> tdd-vertical-slices."""
    r = run_detector("--json", "quiero hacer tdd")
    assert r.returncode == 0, f"stderr={r.stderr}"
    results = json.loads(r.stdout.strip())
    assert "tdd-vertical-slices" in results


def test_required_skills_have_trigger_frontmatter():
    """AC2: all 10 required skills have trigger.keywords in SKILL.md."""
    for skill in REQUIRED_SKILLS:
        skill_md = SKILLS_DIR / skill / "SKILL.md"
        assert skill_md.exists(), f"SKILL.md not found for: {skill}"
        content = skill_md.read_text()
        assert "trigger:" in content, f"No trigger: block in {skill}"
        assert "keywords:" in content, f"No keywords: in {skill}"


def test_trigger_map_exists():
    """AC3: skill-trigger-map.md exists and has markdown table."""
    assert TRIGGER_MAP.exists()
    content = TRIGGER_MAP.read_text()
    assert "|" in content  # markdown table
    assert "Skill" in content or "skill" in content.lower()
    assert "Keywords" in content or "keywords" in content.lower()


def test_case_insensitive_match():
    """AC4: detection is case-insensitive."""
    r = run_detector("--json", "I WANT TO DO TDD")
    assert r.returncode == 0
    results = json.loads(r.stdout.strip())
    assert "tdd-vertical-slices" in results


def test_multi_match():
    """AC5: input matching multiple skills returns all of them."""
    # "spec" triggers spec-driven-development; "grafo" triggers knowledge-graph
    r = run_detector("--json", "necesito un spec y un grafo")
    assert r.returncode == 0
    results = json.loads(r.stdout.strip())
    assert "spec-driven-development" in results
    assert "knowledge-graph" in results


def test_list_mode_shows_table():
    """AC6: --list shows skill-keywords table."""
    r = run_detector("--list")
    assert r.returncode == 0
    # Should print a header row and at least one data row
    lines = [l for l in r.stdout.splitlines() if l.strip()]
    assert len(lines) >= 3  # header + separator + >=1 data row


def test_preturn_hook_registered():
    """AC7: PreTurn hook for skill-keyword-detector exists in settings.json."""
    assert SETTINGS_JSON.exists()
    data = json.loads(SETTINGS_JSON.read_text())
    hooks = data.get("hooks", {})
    preturn = hooks.get("PreTurn", [])
    assert preturn, "PreTurn key missing from hooks"
    found = False
    for entry in preturn:
        for hook in entry.get("hooks", []):
            if "skill-keyword-detector" in hook.get("command", ""):
                found = True
    assert found, "skill-keyword-detector.sh not found in PreTurn hooks"


def test_no_match_returns_empty_array():
    """AC1/AC5: input with no matching keywords returns empty JSON array."""
    r = run_detector("--json", "xyzzy-frobnicator-quux-nonsense-text")
    assert r.returncode == 0
    results = json.loads(r.stdout.strip())
    assert isinstance(results, list)
    assert results == []
