#!/usr/bin/env python3
"""
embeddings-cache.py — SPEC-199 Phase 1: local sentence-transformers embedding cache.

Computes embeddings for text strings using sentence-transformers (all-MiniLM-L6-v2,
384 dims) and caches results in a SQLite DB to avoid recomputation.

Usage:
    python3 scripts/embeddings-cache.py --text "some draft text" --db ~/.savia/embeddings.db
    python3 scripts/embeddings-cache.py --file /path/to/draft.txt --db ~/.savia/embeddings.db
    python3 scripts/embeddings-cache.py --self-test

Output (stdout, JSON):
    {"hash": "sha256...", "embedding_dim": 384, "from_cache": true, "embedding": [0.1, ...]}

Environment:
    SAVIA_EMBEDDINGS_DB  override default DB path
    SAVIA_EMBEDDINGS_MODEL  override model name (default: all-MiniLM-L6-v2)

Ref: SPEC-199 docs/propuestas/SPEC-199-historical-context-tribunal-rounds.md
"""

import argparse
import hashlib
import json
import os
import sqlite3
import struct
import sys
from pathlib import Path

DEFAULT_DB = os.path.expanduser(
    os.environ.get("SAVIA_EMBEDDINGS_DB", "~/.savia/embeddings.db")
)
DEFAULT_MODEL = os.environ.get("SAVIA_EMBEDDINGS_MODEL", "all-MiniLM-L6-v2")
SCHEMA_VERSION = 1


def _init_db(db_path: str) -> sqlite3.Connection:
    Path(db_path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS embeddings (
            text_hash TEXT PRIMARY KEY,
            model TEXT NOT NULL,
            embedding BLOB NOT NULL,
            dim INTEGER NOT NULL,
            ts TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_emb_hash ON embeddings(text_hash)")
    conn.commit()
    return conn


def _text_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _blob_to_list(blob: bytes, dim: int) -> list:
    return list(struct.unpack(f"{dim}f", blob))


def _list_to_blob(vec: list) -> bytes:
    return struct.pack(f"{len(vec)}f", *vec)


def compute_embedding(text: str, model_name: str = DEFAULT_MODEL, db_path: str = DEFAULT_DB) -> dict:
    """Return embedding for text, using cache if available. Never raises on model absence."""
    h = _text_hash(text)
    conn = _init_db(db_path)

    # Check cache
    row = conn.execute(
        "SELECT embedding, dim FROM embeddings WHERE text_hash=? AND model=?",
        (h, model_name)
    ).fetchone()
    if row:
        conn.close()
        return {"hash": h, "embedding_dim": row[1], "from_cache": True,
                "embedding": _blob_to_list(row[0], row[1])}

    # Compute
    try:
        from sentence_transformers import SentenceTransformer  # type: ignore
    except ImportError:
        conn.close()
        return {"hash": h, "embedding_dim": 0, "from_cache": False,
                "embedding": [], "error": "sentence-transformers not installed"}

    model = SentenceTransformer(model_name)
    vec = model.encode(text, normalize_embeddings=True).tolist()
    dim = len(vec)
    blob = _list_to_blob(vec)

    conn.execute(
        "INSERT OR REPLACE INTO embeddings(text_hash, model, embedding, dim) VALUES (?,?,?,?)",
        (h, model_name, blob, dim)
    )
    conn.commit()
    conn.close()
    return {"hash": h, "embedding_dim": dim, "from_cache": False, "embedding": vec}


def _self_test() -> int:
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        text = "test draft for embedding cache"
        # First call: compute
        r1 = compute_embedding(text, db_path=tmp_db)
        assert r1["hash"] == _text_hash(text), "hash mismatch"
        # Second call: cache hit
        r2 = compute_embedding(text, db_path=tmp_db)
        assert r2["from_cache"] is True, "second call should be from cache"
        assert r1["hash"] == r2["hash"], "hash stable"
        # Empty text
        r3 = compute_embedding("", db_path=tmp_db)
        assert r3["hash"] == _text_hash(""), "empty text hash"
        print("self-test OK")
        return 0
    except AssertionError as e:
        print(f"self-test FAIL: {e}", file=sys.stderr)
        return 1
    finally:
        os.unlink(tmp_db)


def main():
    parser = argparse.ArgumentParser(description="Embedding cache — SPEC-199")
    parser.add_argument("--text", help="Text to embed")
    parser.add_argument("--file", help="File containing text to embed")
    parser.add_argument("--db", default=DEFAULT_DB, help="SQLite DB path")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="sentence-transformers model")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        sys.exit(_self_test())

    if args.file:
        text = Path(args.file).read_text(encoding="utf-8")
    elif args.text:
        text = args.text
    else:
        parser.print_help()
        sys.exit(2)

    result = compute_embedding(text, model_name=args.model, db_path=args.db)
    # Don't print full embedding by default (large)
    out = {k: v for k, v in result.items() if k != "embedding"}
    out["embedding_len"] = len(result.get("embedding", []))
    print(json.dumps(out))


if __name__ == "__main__":
    main()
