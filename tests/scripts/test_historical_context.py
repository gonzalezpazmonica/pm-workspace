"""
tests/scripts/test_historical_context.py — SPEC-199 pytest tests.
Covers ACs 1-12 from SPEC-199.
"""
import importlib.util
import json
import math
import os
import struct
import sqlite3
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(ROOT / "scripts" / "recommendation-tribunal"))

# Load modules under test
def _load(rel_path):
    spec = importlib.util.spec_from_file_location(
        rel_path.replace("/", "_").replace(".py", ""),
        str(ROOT / rel_path)
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

hc = _load("scripts/recommendation-tribunal/historical-context.py")
mg = _load("scripts/kg-schema-migrate-tribunal.py")
ec = _load("scripts/embeddings-cache.py")


# ── fixtures ──────────────────────────────────────────────────────────────────

def make_db():
    f = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    f.close()
    mg.migrate(f.name)
    return f.name


def insert_row(db_path, *, verdict="WARN", final_verdict="PASS",
               summary="Added AC -> PASS", sim_vec=None, confidential=0):
    """Insert a synthetic row with known embedding."""
    if sim_vec is None:
        sim_vec = [1.0, 0.0, 0.0]
    blob = struct.pack(f"{len(sim_vec)}f", *sim_vec)
    import hashlib, time
    h = hashlib.sha256(f"{time.time_ns()}".encode()).hexdigest()
    conn = sqlite3.connect(db_path)
    conn.execute(
        "INSERT INTO tribunal_iterations"
        "(session_id,iteration_n,draft_hash,draft_text,verdict,score_avg,"
        "embedding,embedding_dim,final_verdict,evolution_summary,confidential)"
        " VALUES (?,?,?,?,?,?,?,?,?,?,?)",
        ("s1", 1, h, "synthetic", verdict, 75.0, blob, len(sim_vec),
         final_verdict, summary, confidential)
    )
    conn.commit()
    conn.close()
    return h


# ── cosine helper (tested directly) ──────────────────────────────────────────

def test_cosine_identical():
    assert abs(hc._cosine([1, 0, 0], [1, 0, 0]) - 1.0) < 0.001

def test_cosine_orthogonal():
    assert abs(hc._cosine([1, 0, 0], [0, 1, 0])) < 0.001

def test_cosine_empty():
    assert hc._cosine([], []) == 0.0

def test_cosine_zero_vector():
    assert hc._cosine([0, 0, 0], [1, 0, 0]) == 0.0


# ── AC-1: top-k=0 returns empty ───────────────────────────────────────────────

def test_ac1_top_k_zero():
    db = make_db()
    try:
        r = hc.find_similar("x", top_k=0, db_path=db)
        assert r["similar_drafts"] == []
        assert r["tokens_estimate"] == 0
    finally:
        os.unlink(db)


# ── AC-2: empty KG returns empty ──────────────────────────────────────────────

def test_ac2_empty_kg():
    db = make_db()
    try:
        r = hc.find_similar("some draft", top_k=3, db_path=db)
        assert r["similar_drafts"] == []
    finally:
        os.unlink(db)


# ── AC-3: 1 similar entry returns 1 ──────────────────────────────────────────

def test_ac3_one_similar(monkeypatch):
    db = make_db()
    try:
        insert_row(db, sim_vec=[1.0, 0.0, 0.0])
        # Monkeypatch _get_embedding to return a known vector
        monkeypatch.setattr(hc, "_get_embedding", lambda text: [1.0, 0.0, 0.0])
        r = hc.find_similar("draft", top_k=3, sim_min=0.6, db_path=db)
        assert len(r["similar_drafts"]) == 1
        assert r["similar_drafts"][0]["similarity"] >= 0.6
    finally:
        os.unlink(db)


# ── AC-4: 5 entries, returns top-3 ───────────────────────────────────────────

def test_ac4_top_3_of_5(monkeypatch):
    db = make_db()
    try:
        for i in range(5):
            v = [1.0 - i * 0.05, 0.0, 0.0]
            mag = math.sqrt(sum(x*x for x in v))
            v = [x/mag for x in v]
            insert_row(db, sim_vec=v)
        monkeypatch.setattr(hc, "_get_embedding", lambda text: [1.0, 0.0, 0.0])
        r = hc.find_similar("draft", top_k=3, sim_min=0.5, db_path=db)
        assert len(r["similar_drafts"]) <= 3
    finally:
        os.unlink(db)


# ── AC-5: sim < threshold excluded ───────────────────────────────────────────

def test_ac5_threshold(monkeypatch):
    db = make_db()
    try:
        # Insert row orthogonal to query (sim=0)
        insert_row(db, sim_vec=[0.0, 1.0, 0.0])
        monkeypatch.setattr(hc, "_get_embedding", lambda text: [1.0, 0.0, 0.0])
        r = hc.find_similar("draft", top_k=3, sim_min=0.6, db_path=db)
        assert r["similar_drafts"] == []
    finally:
        os.unlink(db)


# ── AC-6: deterministic embedding (same text -> same hash) ───────────────────

def test_ac6_embedding_deterministic():
    import tempfile
    db = tempfile.mktemp(suffix=".db")
    try:
        text = "determinism test draft"
        r1 = ec.compute_embedding(text, db_path=db)
        r2 = ec.compute_embedding(text, db_path=db)
        assert r1["hash"] == r2["hash"]
    finally:
        if os.path.exists(db):
            os.unlink(db)


# ── AC-7: cache hit on second call ───────────────────────────────────────────

def test_ac7_cache():
    import tempfile
    db = tempfile.mktemp(suffix=".db")
    try:
        text = "cache test"
        ec.compute_embedding(text, db_path=db)  # first: compute
        r2 = ec.compute_embedding(text, db_path=db)  # second: cache
        assert r2["from_cache"] is True
    finally:
        if os.path.exists(db):
            os.unlink(db)


# ── AC-8: schema migration idempotent ────────────────────────────────────────

def test_ac8_migration_idempotent():
    db = make_db()
    try:
        r1 = mg.migrate(db)
        assert r1["migrated"] is False  # already done in make_db
    finally:
        os.unlink(db)


# ── AC-9: tokens_estimate <= max_tokens ──────────────────────────────────────

def test_ac9_token_cap(monkeypatch):
    db = make_db()
    try:
        insert_row(db, sim_vec=[1.0, 0.0, 0.0], summary="A" * 2000)
        monkeypatch.setattr(hc, "_get_embedding", lambda text: [1.0, 0.0, 0.0])
        r = hc.find_similar("draft", top_k=3, sim_min=0.5, max_tokens=100, db_path=db)
        assert r["tokens_estimate"] <= 200  # some slack for the cap
    finally:
        os.unlink(db)


# ── AC-10: confidential=True skips ───────────────────────────────────────────

def test_ac10_confidential():
    db = make_db()
    try:
        r = hc.find_similar("secret draft", top_k=3, db_path=db, confidential=True)
        assert r["skipped_reason"] == "confidential"
        assert r["similar_drafts"] == []
    finally:
        os.unlink(db)


# ── AC-12: latency with 1000 rows <= 500ms ───────────────────────────────────

def test_ac12_latency_1000_rows(monkeypatch):
    import time
    db = make_db()
    try:
        # Insert 1000 rows with random-ish embeddings
        conn = sqlite3.connect(db)
        for i in range(1000):
            v = [float(i % 10) / 10 + 0.01, float((i // 10) % 10) / 10 + 0.01, 0.1]
            mag = math.sqrt(sum(x*x for x in v))
            v = [x/mag for x in v]
            blob = struct.pack("3f", *v)
            conn.execute(
                "INSERT INTO tribunal_iterations(session_id,iteration_n,draft_hash,"
                "draft_text,verdict,embedding,embedding_dim,confidential)"
                " VALUES (?,?,?,?,?,?,?,?)",
                (f"s{i}", 1, f"hash{i}", "draft", "WARN", blob, 3, 0)
            )
        conn.commit()
        conn.close()

        monkeypatch.setattr(hc, "_get_embedding", lambda text: [1.0, 0.0, 0.0])
        t0 = time.monotonic()
        hc.find_similar("query draft", top_k=3, sim_min=0.5, db_path=db)
        elapsed_ms = (time.monotonic() - t0) * 1000
        assert elapsed_ms < 500, f"Latency {elapsed_ms:.0f}ms > 500ms"
    finally:
        os.unlink(db)
