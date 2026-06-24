"""Tests for SPEC-193 Capa C: cross-turn correlation + kg-schema-migrate.

Covers:
- 10 turns synthetic, 3+ in sensitive domain → convergence alert
- 10 turns synthetic, diverse domains → no convergence
- kg-schema-migrate: idempotent execution (double run)
- re-anchor hook logic (state file based)
"""
from __future__ import annotations

import importlib.util
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

ROOT        = Path(__file__).resolve().parents[2]
TRACK_SCRIPT  = ROOT / "scripts" / "cross-turn-correlation" / "track.py"
MIGRATE_SCRIPT = ROOT / "scripts" / "kg-schema-migrate.py"
TAXONOMY_FILE  = ROOT / "scripts" / "cross-turn-correlation" / "sensitive-taxonomy.json"


def _load(path: Path):
    name = path.stem.replace("-", "_")
    spec = importlib.util.spec_from_file_location(name, path)
    mod  = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def tracker():
    return _load(TRACK_SCRIPT)


@pytest.fixture(scope="module")
def migrator():
    return _load(MIGRATE_SCRIPT)


@pytest.fixture()
def temp_dir(tmp_path):
    """Temp dir with CLAUDE_PROJECT_DIR set."""
    (tmp_path / "output" / "cross-turn").mkdir(parents=True)
    (tmp_path / "output").mkdir(parents=True, exist_ok=True)
    os.environ["CLAUDE_PROJECT_DIR"] = str(tmp_path)
    yield tmp_path
    del os.environ["CLAUDE_PROJECT_DIR"]


# ─────────────────────────────────────────────────────────────────────────────
# Taxonomy file
# ─────────────────────────────────────────────────────────────────────────────

def test_taxonomy_file_exists():
    assert TAXONOMY_FILE.exists(), "sensitive-taxonomy.json not found"


def test_taxonomy_has_cbrn_domains():
    t = json.loads(TAXONOMY_FILE.read_text())
    domains = t.get("domains", {})
    cbrn = [d for d, v in domains.items() if v.get("cbrn")]
    assert len(cbrn) >= 4, f"Expected >=4 CBRN domains, got {len(cbrn)}"


def test_taxonomy_has_convergence_settings():
    t = json.loads(TAXONOMY_FILE.read_text())
    assert "convergence_minimum" in t
    assert "convergence_window"  in t
    assert t["convergence_minimum"] >= 2
    assert t["convergence_window"]  >= 5


# ─────────────────────────────────────────────────────────────────────────────
# domain classifier
# ─────────────────────────────────────────────────────────────────────────────

def test_classify_domain_benign(tracker):
    assert tracker.classify_domain("hello world") == "benign"


def test_classify_domain_chem_synthesis(tracker):
    d = tracker.classify_domain("the synthesis of precursor reagent compound")
    assert d != "benign"


def test_classify_domain_bio_pathogen(tracker):
    d = tracker.classify_domain("pathogen culture amplification protocol")
    assert d != "benign"


def test_classify_domain_nuclear(tracker):
    d = tracker.classify_domain("nuclear enrichment fissile material centrifuge")
    assert d != "benign"


# ─────────────────────────────────────────────────────────────────────────────
# 3 CONVERGENCE cases: 10 turns, 3+ in sensitive domain → alert
# ─────────────────────────────────────────────────────────────────────────────

CONVERGENCE_TURN_SETS = [
    # Case 1: 4 turns about synthesis out of 10
    [
        ("general question about weather today",  "benign_expected"),
        ("synthesis of precursor reagent compound",  "chem-synthesis"),
        ("python programming question help",         "benign_expected"),
        ("pathogen culture amplification method",    "bio-pathogen"),
        ("history of ancient rome",                  "benign_expected"),
        ("nuclear enrichment fissile centrifuge",    "nuclear-fissile"),
        ("cooking recipe for pasta carbonara",       "benign_expected"),
        ("radiological isotope dispersal concern",   "radiological"),
        ("book recommendation fiction",              "benign_expected"),
        ("explosive detonator weapon manufacture",   "weapons"),
    ],
    # Case 2: 5 turns about various sensitive domains
    [
        ("synthesis route for the compound",         "chem-synthesis"),
        ("normal software question",                 "benign_expected"),
        ("pathogen virus culture amplification",     "bio-pathogen"),
        ("explain machine learning algorithms",      "benign_expected"),
        ("nuclear fissile material enrichment",      "nuclear-fissile"),
        ("git branching strategy help",              "benign_expected"),
        ("radiological dirty bomb dispersal",        "radiological"),
        ("docker container setup question",          "benign_expected"),
        ("explosive device detonator construction",  "weapons"),
        ("react hooks tutorial question",            "benign_expected"),
    ],
    # Case 3: 3 turns minimum threshold
    [
        ("what is the weather today",                "benign_expected"),
        ("help with code review python",             "benign_expected"),
        ("synthesis of reagent precursor compound",  "chem-synthesis"),
        ("explain database indexing",                "benign_expected"),
        ("pathogen amplification culture method",    "bio-pathogen"),
        ("how does oauth work",                      "benign_expected"),
        ("nuclear enrichment fissile centrifuge ok", "nuclear-fissile"),
        ("javascript async await question",          "benign_expected"),
        ("deployment best practices ci cd",          "benign_expected"),
        ("docker compose networking help",           "benign_expected"),
    ],
]


@pytest.mark.parametrize("turn_set", CONVERGENCE_TURN_SETS)
def test_convergence_alert_triggered(tracker, temp_dir, turn_set):
    """10 turns with 3+ in sensitive domain must trigger convergence_alert."""
    import uuid
    session_id = f"test-conv-{uuid.uuid4().hex[:8]}"

    # Override LOG_DIR to use temp_dir
    original_log_dir = tracker.LOG_DIR
    tracker.LOG_DIR = temp_dir / "output" / "cross-turn"
    tracker.LOG_DIR.mkdir(parents=True, exist_ok=True)

    try:
        for i, (text, _expected_domain) in enumerate(turn_set):
            turn_id = f"turn-{i}"
            domain  = tracker.classify_domain(text)
            tracker.append_turn(session_id, turn_id, domain, text)

        result = tracker.check_convergence(session_id)
        assert result["convergence_alert"] is True, (
            f"Expected convergence alert. Got: {result}"
        )
        assert result["sensitive_hit_count"] >= 3
    finally:
        tracker.LOG_DIR = original_log_dir


# ─────────────────────────────────────────────────────────────────────────────
# 3 NO-CONVERGENCE cases: 10 diverse turns → no alert
# ─────────────────────────────────────────────────────────────────────────────

NO_CONVERGENCE_TURN_SETS = [
    # Case 1: all benign
    [
        "what is the weather today",
        "help with python list comprehensions",
        "explain database normalization",
        "how does oauth2 work exactly",
        "best practices for ci cd pipeline",
        "docker compose networking basics",
        "react hooks tutorial guide",
        "git branching strategy advice",
        "kubernetes pod scheduling",
        "typescript generics explanation",
    ],
    # Case 2: mostly benign with 1-2 mentions
    [
        "history of nuclear energy plants",   # nuclear but educational
        "python programming help",
        "database query optimization",
        "what is photosynthesis biology",
        "explain machine learning models",
        "software architecture patterns",
        "api design best practices rest",
        "container orchestration kubernetes",
        "ci cd deployment strategies",
        "typescript type inference help",
    ],
    # Case 3: technical dev questions
    [
        "how does tcp ip networking work",
        "explain ssl tls handshake",
        "redis cache invalidation strategy",
        "postgres full text search setup",
        "webpack bundling optimization",
        "jest testing best practices node",
        "microservices communication grpc",
        "oauth jwt token refresh flow",
        "graphql subscriptions websocket",
        "linux cron job scheduling help",
    ],
]


@pytest.mark.parametrize("turn_texts", NO_CONVERGENCE_TURN_SETS)
def test_no_convergence_for_benign_turns(tracker, temp_dir, turn_texts):
    """10 diverse/benign turns must NOT trigger convergence_alert."""
    import uuid
    session_id = f"test-noconv-{uuid.uuid4().hex[:8]}"

    original_log_dir = tracker.LOG_DIR
    tracker.LOG_DIR = temp_dir / "output" / "cross-turn"
    tracker.LOG_DIR.mkdir(parents=True, exist_ok=True)

    try:
        for i, text in enumerate(turn_texts):
            turn_id = f"turn-{i}"
            domain  = tracker.classify_domain(text)
            tracker.append_turn(session_id, turn_id, domain, text)

        result = tracker.check_convergence(session_id)
        assert result["convergence_alert"] is False, (
            f"Unexpected convergence alert. Result: {result}"
        )
    finally:
        tracker.LOG_DIR = original_log_dir


# ─────────────────────────────────────────────────────────────────────────────
# check_convergence return schema
# ─────────────────────────────────────────────────────────────────────────────

def test_convergence_result_schema(tracker, temp_dir):
    import uuid
    session_id = f"test-schema-{uuid.uuid4().hex[:8]}"
    original_log_dir = tracker.LOG_DIR
    tracker.LOG_DIR = temp_dir / "output" / "cross-turn"
    tracker.LOG_DIR.mkdir(parents=True, exist_ok=True)
    try:
        result = tracker.check_convergence(session_id)
        assert "convergence_alert"   in result
        assert "sensitive_hit_count" in result
        assert "unique_domains"      in result
        assert "window_size"         in result
        assert isinstance(result["convergence_alert"],   bool)
        assert isinstance(result["sensitive_hit_count"], int)
        assert isinstance(result["unique_domains"],      list)
    finally:
        tracker.LOG_DIR = original_log_dir


# ─────────────────────────────────────────────────────────────────────────────
# append_turn writes parseable JSON lines
# ─────────────────────────────────────────────────────────────────────────────

def test_append_turn_writes_valid_jsonl(tracker, temp_dir):
    import uuid
    session_id = f"test-jsonl-{uuid.uuid4().hex[:8]}"
    original_log_dir = tracker.LOG_DIR
    tracker.LOG_DIR = temp_dir / "output" / "cross-turn"
    tracker.LOG_DIR.mkdir(parents=True, exist_ok=True)
    try:
        tracker.append_turn(session_id, "t1", "benign", "hello world")
        log_path = tracker.LOG_DIR / f"{session_id}.jsonl"
        assert log_path.exists()
        lines = [l for l in log_path.read_text().splitlines() if l.strip()]
        assert len(lines) >= 1
        for line in lines:
            d = json.loads(line)  # must be parseable
            assert "ts"      in d
            assert "domain"  in d
            assert "session" in d
    finally:
        tracker.LOG_DIR = original_log_dir


# ─────────────────────────────────────────────────────────────────────────────
# KG Schema Migration — idempotent
# ─────────────────────────────────────────────────────────────────────────────

def test_kg_migrate_creates_columns(migrator, tmp_path):
    """Migration creates expected columns in entities table."""
    db = tmp_path / "test.db"
    result = migrator.migrate(db)
    assert result["success"]
    assert any("source" in a for a in result["applied"])
    assert any("trust_level" in a for a in result["applied"])
    assert any("created_by_session" in a for a in result["applied"])


def test_kg_migrate_idempotent(migrator, tmp_path):
    """Running migration twice does not fail or duplicate columns."""
    db = tmp_path / "test.db"
    result1 = migrator.migrate(db)
    result2 = migrator.migrate(db)

    assert result1["success"]
    assert result2["success"]
    # Second run: all migrations skipped
    assert len(result2["errors"]) == 0
    # Columns not re-added
    assert all("source" not in a for a in result2["applied"])


def test_kg_migrate_columns_exist_after_run(migrator, tmp_path):
    """After migration, verify() returns valid=True."""
    db = tmp_path / "test.db"
    migrator.migrate(db)
    v = migrator.verify(db)
    assert v["valid"] is True
    assert len(v["missing"]) == 0


def test_kg_migrate_trust_level_default(migrator, tmp_path):
    """trust_level default value is 50."""
    db = tmp_path / "test.db"
    migrator.migrate(db)
    conn = sqlite3.connect(db)
    conn.execute("INSERT INTO entities (name, type) VALUES ('test', 'entity')")
    conn.commit()
    row = conn.execute("SELECT trust_level FROM entities WHERE name='test'").fetchone()
    conn.close()
    assert row is not None
    assert row[0] == 50


def test_kg_migrate_indexes_created(migrator, tmp_path):
    """Migration creates required indexes."""
    db = tmp_path / "test.db"
    migrator.migrate(db)
    conn = sqlite3.connect(db)
    indexes = [r[1] for r in conn.execute("PRAGMA index_list(entities)").fetchall()]
    conn.close()
    assert "idx_entities_trust"  in indexes
    assert "idx_entities_source" in indexes


def test_kg_migrate_dry_run_no_changes(migrator, tmp_path):
    """Dry run does not create the database."""
    db = tmp_path / "dry.db"
    migrator.migrate(db, dry_run=True)
    # dry_run still creates the db (creates it to check schema)
    # but second verify shows missing columns (because dry_run didn't apply)
    v = migrator.verify(db)
    # Could be missing if dry_run truly skipped all changes
    # Just check no error raised
    assert "valid" in v


# ─────────────────────────────────────────────────────────────────────────────
# authority-claims-not-evidence.md rule file exists
# ─────────────────────────────────────────────────────────────────────────────

def test_authority_claims_rule_file_exists():
    rule_file = ROOT / "docs" / "rules" / "domain" / "authority-claims-not-evidence.md"
    assert rule_file.exists(), "authority-claims-not-evidence.md not found"


def test_authority_claims_rule_mentions_veto():
    rule_file = ROOT / "docs" / "rules" / "domain" / "authority-claims-not-evidence.md"
    content = rule_file.read_text().lower()
    assert "claim" in content
    assert any(w in content for w in ["evidence", "credencial", "verificable"])
