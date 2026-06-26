#!/usr/bin/env python3
"""historical-context.py — SPEC-199: Historical-context conditioning for tribunal rounds.

Calculates embedding of the current draft, searches the tribunal_iterations DB
for the K most similar historical drafts, and returns a context block that the
orchestrator can inject into judge prompts.

Also persists the current draft in the DB for future iterations.

CLI:
    python3 scripts/recommendation-tribunal/historical-context.py \\
        --draft TEXT \\
        --verdict-json FILE \\
        --top-k 3 \\
        --similarity-threshold 0.6 \\
        --session-id SESSION_ID \\
        --iteration N

Output JSON:
{
  "similar_drafts": [
    {
      "hash": "abc...",
      "similarity": 0.78,
      "verdict": "WARN->PASS in 2 iter",
      "summary": "...",
      "evolution": "..."
    }
  ],
  "context_text": "Drafts similares en historia...",
  "tokens_estimate": 420,
  "is_zero_sc": true
}
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import sys
from pathlib import Path

import numpy as np

# Resolve script dir to locate sibling modules
_SCRIPT_DIR = Path(__file__).resolve().parent
_ROOT_DIR = _SCRIPT_DIR.parent.parent

# Add scripts/ to path so we can import embeddings_cache
if str(_ROOT_DIR / "scripts") not in sys.path:
    sys.path.insert(0, str(_ROOT_DIR / "scripts"))

import importlib.util as _ilu

def _load_embeddings_cache():
    spec = _ilu.spec_from_file_location(
        "embeddings_cache",
        str(_ROOT_DIR / "scripts" / "embeddings-cache.py")
    )
    mod = _ilu.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

_ec = _load_embeddings_cache()
compute_embedding_cached = _ec.compute_embedding_cached
cosine_similarity = _ec.cosine_similarity

# ── DB helpers ────────────────────────────────────────────────────────────────

DEFAULT_DB = Path(os.environ.get(
    "SAVIA_TRIBUNAL_HIST_DB",
    Path.home() / ".savia" / "tribunal-iterations.db"
))

MAX_TOKENS_DEFAULT = int(os.environ.get("SAVIA_TRIBUNAL_HIST_MAX_TOKENS", "500"))

# Rough token estimator (GPT-style: 1 token ≈ 4 chars)
_CHARS_PER_TOKEN = 4


def _tokens(text: str) -> int:
    return max(1, len(text) // _CHARS_PER_TOKEN)


def _ensure_schema(con: sqlite3.Connection) -> None:
    """Ensure table exists (fail-soft schema migration inline)."""
    con.executescript("""
    CREATE TABLE IF NOT EXISTS tribunal_iterations (
        iteration_id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        iteration_n INTEGER NOT NULL,
        draft_hash TEXT NOT NULL,
        draft_text TEXT,
        verdict TEXT,
        score_avg REAL,
        embedding BLOB,
        final_verdict TEXT,
        evolution_summary TEXT,
        confidential INTEGER DEFAULT 0,
        ts TEXT DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX IF NOT EXISTS idx_tribunal_draft_hash ON tribunal_iterations(draft_hash);
    CREATE INDEX IF NOT EXISTS idx_tribunal_session ON tribunal_iterations(session_id);
    """)
    con.commit()


def _open_db(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(str(db_path))
    con.row_factory = sqlite3.Row
    _ensure_schema(con)
    return con


def _draft_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _is_confidential(text: str) -> bool:
    """Heuristic: draft contains 'confidential' keyword."""
    return "confidential" in text.lower()


def _embedding_to_blob(emb: np.ndarray) -> bytes:
    return emb.astype(np.float32).tobytes()


def _blob_to_embedding(blob: bytes) -> np.ndarray:
    return np.frombuffer(blob, dtype=np.float32)


# ── Core logic ────────────────────────────────────────────────────────────────


def search_similar(
    db_path: Path,
    query_emb: np.ndarray,
    top_k: int,
    threshold: float,
    exclude_session: str | None = None,
) -> list[dict]:
    """Return up to top_k rows from tribunal_iterations with cosine_sim >= threshold.

    Excludes confidential entries and (optionally) rows from the same session.
    Results are sorted by similarity descending.
    """
    if top_k <= 0:
        return []

    if not db_path.exists():
        return []

    con = _open_db(db_path)
    try:
        cur = con.execute(
            "SELECT draft_hash, draft_text, verdict, evolution_summary, "
            "final_verdict, iteration_n, embedding "
            "FROM tribunal_iterations "
            "WHERE confidential = 0 AND embedding IS NOT NULL"
        )
        rows = cur.fetchall()
    finally:
        con.close()

    if not rows:
        return []

    scored: list[tuple[float, dict]] = []
    for row in rows:
        try:
            row_emb = _blob_to_embedding(row["embedding"])
        except Exception:
            continue
        sim = cosine_similarity(query_emb, row_emb)
        if sim < threshold:
            continue
        verdict_label = row["verdict"] or ""
        final_v = row["final_verdict"] or ""
        evo = row["evolution_summary"] or ""
        if final_v and final_v != verdict_label:
            verdict_display = f"{verdict_label}->{final_v} in {row['iteration_n']} iter"
        else:
            verdict_display = verdict_label

        scored.append((sim, {
            "hash": row["draft_hash"],
            "similarity": round(sim, 4),
            "verdict": verdict_display,
            "summary": (row["draft_text"] or "")[:200],
            "evolution": evo,
        }))

    scored.sort(key=lambda x: x[0], reverse=True)
    return [item for _, item in scored[:top_k]]


def build_context_text(similar: list[dict], max_tokens: int) -> str:
    """Build a compact text block summarizing historical similar drafts."""
    if not similar:
        return ""
    lines = ["Historical drafts similares:"]
    current_tokens = _tokens(lines[0])
    for i, s in enumerate(similar, 1):
        line = (
            f"{i}. sim={s['similarity']:.2f} verdict={s['verdict']}"
        )
        if s["evolution"]:
            line += f" | evolution: {s['evolution']}"
        if s["summary"]:
            line += f" | draft_excerpt: {s['summary'][:100]}"
        t = _tokens(line)
        if current_tokens + t > max_tokens:
            break
        lines.append(line)
        current_tokens += t
    return "\n".join(lines)


def persist_draft(
    db_path: Path,
    session_id: str,
    iteration_n: int,
    draft_text: str,
    draft_hash: str,
    verdict: str,
    score_avg: float | None,
    embedding: np.ndarray,
    final_verdict: str = "",
    evolution_summary: str = "",
    confidential: bool = False,
) -> None:
    """Insert current draft into DB for future iterations."""
    if confidential:
        return  # AC-10: confidential drafts are never persisted

    con = _open_db(db_path)
    try:
        con.execute(
            "INSERT INTO tribunal_iterations "
            "(session_id, iteration_n, draft_hash, draft_text, verdict, "
            "score_avg, embedding, final_verdict, evolution_summary, confidential) "
            "VALUES (?,?,?,?,?,?,?,?,?,?)",
            (
                session_id,
                iteration_n,
                draft_hash,
                draft_text,
                verdict,
                score_avg,
                _embedding_to_blob(embedding),
                final_verdict,
                evolution_summary,
                0,
            ),
        )
        con.commit()
    finally:
        con.close()


def historical_context(
    draft: str,
    verdict_data: dict | None,
    top_k: int,
    threshold: float,
    session_id: str,
    iteration_n: int,
    db_path: Path,
    max_tokens: int,
) -> dict:
    """Main entry point. Returns the context dict."""
    # Check empty DB early (before computing embeddings)
    db_exists = db_path.exists()

    if top_k <= 0:
        # Still need to persist current draft, but return empty context
        emb, _, fallback = compute_embedding_cached(draft)
        is_zero_sc = (not db_exists) or fallback
        verdict_str = verdict_data.get("verdict", "") if verdict_data else ""
        score_avg = verdict_data.get("score_avg") if verdict_data else None
        confidential = _is_confidential(draft)
        if not confidential:
            persist_draft(
                db_path, session_id, iteration_n,
                draft, _draft_hash(draft),
                verdict_str, score_avg, emb,
                confidential=confidential,
            )
        return {
            "similar_drafts": [],
            "context_text": "",
            "tokens_estimate": 0,
            "is_zero_sc": is_zero_sc,
        }

    # Compute embedding for current draft
    emb, _cached, fallback = compute_embedding_cached(draft)

    # is_zero_sc: true when no history available or fallback vector
    row_count = 0
    if db_exists:
        try:
            con = _open_db(db_path)
            cur = con.execute(
                "SELECT COUNT(*) FROM tribunal_iterations "
                "WHERE confidential = 0 AND embedding IS NOT NULL"
            )
            row_count = cur.fetchone()[0]
            con.close()
        except Exception:
            row_count = 0

    is_zero_sc = (row_count == 0) or fallback

    # Search for similar drafts
    similar: list[dict] = []
    if row_count > 0 and not fallback:
        similar = search_similar(db_path, emb, top_k, threshold)

    context_text = build_context_text(similar, max_tokens)
    tokens_est = _tokens(context_text) if context_text else 0

    # Persist current draft
    verdict_str = verdict_data.get("verdict", "") if verdict_data else ""
    score_avg_val = verdict_data.get("score_avg") if verdict_data else None
    confidential = _is_confidential(draft)
    if not confidential:
        persist_draft(
            db_path, session_id, iteration_n,
            draft, _draft_hash(draft),
            verdict_str, score_avg_val, emb,
            confidential=confidential,
        )

    return {
        "similar_drafts": similar,
        "context_text": context_text,
        "tokens_estimate": tokens_est,
        "is_zero_sc": is_zero_sc,
    }


# ── CLI ───────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        description="SPEC-199: Historical context conditioning for tribunal rounds."
    )
    p.add_argument("--draft", required=True, help="Current draft text")
    p.add_argument("--verdict-json", dest="verdict_json", default=None,
                   help="Path to JSON file with current verdict/scores")
    p.add_argument("--top-k", dest="top_k", type=int, default=3,
                   help="Max similar drafts to retrieve")
    p.add_argument("--similarity-threshold", dest="threshold", type=float, default=0.6,
                   help="Min cosine similarity to include a result")
    p.add_argument("--session-id", dest="session_id", default="default",
                   help="Current tribunal session ID")
    p.add_argument("--iteration", dest="iteration_n", type=int, default=0,
                   help="Current iteration number")
    p.add_argument("--db", default=str(DEFAULT_DB),
                   help="SQLite DB path")
    p.add_argument("--max-tokens", dest="max_tokens", type=int,
                   default=MAX_TOKENS_DEFAULT,
                   help="Max tokens for context_text")
    args = p.parse_args(argv)

    # Load verdict data if provided
    verdict_data: dict | None = None
    if args.verdict_json:
        vpath = Path(args.verdict_json)
        if vpath.exists():
            try:
                verdict_data = json.loads(vpath.read_text())
            except Exception:
                verdict_data = None

    result = historical_context(
        draft=args.draft,
        verdict_data=verdict_data,
        top_k=args.top_k,
        threshold=args.threshold,
        session_id=args.session_id,
        iteration_n=args.iteration_n,
        db_path=Path(args.db),
        max_tokens=args.max_tokens,
    )
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
