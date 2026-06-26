#!/usr/bin/env python3
"""embeddings-cache.py — SPEC-199: Embedding cache backed by sentence-transformers.

Model: all-MiniLM-L6-v2 (384 dims).
Cache: ~/.savia/embeddings-cache/<sha256_of_text>.npy (persistent, per-process shared).
Fallback: if sentence-transformers unavailable, returns a zero vector (no crash).

CLI:
    python3 scripts/embeddings-cache.py --text "..." --json
    -> {"embedding_dim": 384, "cached": bool, "fallback": bool}
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

import numpy as np

# ── Constants ────────────────────────────────────────────────────────────────

MODEL_NAME = "all-MiniLM-L6-v2"
EMBEDDING_DIM = 384
CACHE_DIR = Path(os.environ.get("SAVIA_EMBEDDINGS_CACHE_DIR",
                                 Path.home() / ".savia" / "embeddings-cache"))

# ── In-process LRU (avoid repeated disk reads) ───────────────────────────────

_mem_cache: dict[str, np.ndarray] = {}

# ── Helpers ───────────────────────────────────────────────────────────────────


def _text_hash(text: str) -> str:
    """SHA-256 hex of the text (used as cache key)."""
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _cache_path(text_hash: str) -> Path:
    return CACHE_DIR / f"{text_hash}.npy"


def _load_model():
    """Return (model, is_fallback). Never raises."""
    try:
        from sentence_transformers import SentenceTransformer
        return SentenceTransformer(MODEL_NAME), False
    except Exception:
        return None, True


def _fallback_vector() -> np.ndarray:
    """Zero vector of EMBEDDING_DIM as fallback."""
    return np.zeros(EMBEDDING_DIM, dtype=np.float32)


# ── Public API ────────────────────────────────────────────────────────────────


def compute_embedding(text: str) -> np.ndarray:
    """Compute embedding for *text*. No caching. Falls back to zeros on error."""
    model, is_fallback = _load_model()
    if is_fallback or model is None:
        return _fallback_vector()
    try:
        emb = model.encode(text, convert_to_numpy=True, normalize_embeddings=True)
        return emb.astype(np.float32)
    except Exception:
        return _fallback_vector()


def compute_embedding_cached(text: str) -> tuple[np.ndarray, bool, bool]:
    """Return (embedding, was_cached, is_fallback).

    Order of lookup:
    1. In-process memory cache.
    2. Disk cache (~/.savia/embeddings-cache/<hash>.npy).
    3. Compute + persist.
    """
    h = _text_hash(text)

    # 1. memory
    if h in _mem_cache:
        return _mem_cache[h], True, False

    # 2. disk
    cp = _cache_path(h)
    if cp.exists():
        try:
            emb = np.load(str(cp))
            _mem_cache[h] = emb
            return emb, True, False
        except Exception:
            pass

    # 3. compute
    model, is_fallback = _load_model()
    if is_fallback or model is None:
        emb = _fallback_vector()
        _mem_cache[h] = emb
        return emb, False, True

    try:
        emb = model.encode(text, convert_to_numpy=True, normalize_embeddings=True)
        emb = emb.astype(np.float32)
    except Exception:
        emb = _fallback_vector()
        _mem_cache[h] = emb
        return emb, False, True

    # persist
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        np.save(str(cp), emb)
    except Exception:
        pass  # fail-soft: cache miss next time but no crash

    _mem_cache[h] = emb
    return emb, False, False


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """Cosine similarity between two 1-D float32 vectors. Returns 0.0 on error."""
    try:
        na = np.linalg.norm(a)
        nb = np.linalg.norm(b)
        if na == 0.0 or nb == 0.0:
            return 0.0
        return float(np.dot(a, b) / (na * nb))
    except Exception:
        return 0.0


# ── CLI ───────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Compute/cache embeddings for a text.")
    p.add_argument("--text", required=True, help="Text to embed")
    p.add_argument("--json", action="store_true", help="Output JSON summary")
    p.add_argument("--no-cache", action="store_true", help="Skip cache (recompute)")
    args = p.parse_args(argv)

    if args.no_cache:
        emb = compute_embedding(args.text)
        cached = False
        fallback = (emb == 0).all()
    else:
        emb, cached, fallback = compute_embedding_cached(args.text)

    if args.json:
        print(json.dumps({
            "embedding_dim": int(emb.shape[0]),
            "cached": cached,
            "fallback": bool(fallback),
            "hash": _text_hash(args.text),
        }))
    else:
        print(f"embedding_dim={emb.shape[0]} cached={cached} fallback={fallback}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
