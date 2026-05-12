"""f1/duplicate_detection.py — F1 job: detect near-duplicate notes (>70% similarity).

Uses a fast shingling + Jaccard approach (no external deps):
1. Tokenise each file into 3-grams of words (shingles).
2. Estimate Jaccard similarity between pairs using MinHash-lite
   (16 hash functions — fast, good enough for F1 screening).
3. Report pairs with estimated Jaccard >= SIMILARITY_THRESHOLD.

Complexity: O(n * h) where h=16 (hash functions) — scales to thousands of files.
O(n²) pair comparison is avoided by bucketing files into LSH bands.

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F1.
Confidence: MEDIUM (probabilistic estimate, not exact similarity).
"""
from __future__ import annotations

import hashlib
import re
from pathlib import Path
from typing import Any

SIMILARITY_THRESHOLD = 0.70   # report pairs above this Jaccard estimate
NUM_HASHES = 16               # MinHash signature length
NUM_BANDS = 4                 # LSH bands (NUM_HASHES must be divisible)
ROWS_PER_BAND = NUM_HASHES // NUM_BANDS  # 4

# Only run duplicate detection on "content" files (not command/agent boilerplate)
_CONTENT_FRAGMENTS = (
    ".spec.md",
    "docs/specs",
    "docs/decisions",
    "docs/propuestas",
    "/vault/",
    "/raw/",
    "docs/rules",
)

_WORD_RE = re.compile(r"[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]{3,}")
_LARGE_FILE_BYTES = 200_000   # skip very large files (likely auto-generated)


def _is_content_file(path_str: str) -> bool:
    return any(frag in path_str for frag in _CONTENT_FRAGMENTS)


def _shingles(text: str, k: int = 3) -> set[str]:
    """Return set of k-gram word shingles."""
    words = _WORD_RE.findall(text.lower())
    if len(words) < k:
        return set(words)
    return {" ".join(words[i:i + k]) for i in range(len(words) - k + 1)}


def _minhash_signature(shingles: set[str]) -> list[int]:
    """Compute MinHash signature with NUM_HASHES permutations (via seeded MD5)."""
    sig = [2**32] * NUM_HASHES
    for shingle in shingles:
        encoded = shingle.encode("utf-8")
        for i in range(NUM_HASHES):
            h = int(
                hashlib.md5(encoded + i.to_bytes(2, "little")).hexdigest()[:8],
                16,
            )
            if h < sig[i]:
                sig[i] = h
    return sig


def _estimated_jaccard(sig_a: list[int], sig_b: list[int]) -> float:
    matches = sum(a == b for a, b in zip(sig_a, sig_b))
    return matches / NUM_HASHES


def run(files: list[dict]) -> dict:
    """Detect near-duplicate notes.

    Args:
        files: list of file dicts from discovery.

    Returns:
        dict with findings and summary.
    """
    # Filter to content files only
    content_files = [f for f in files if _is_content_file(f["path"])]

    signatures: dict[str, list[int]] = {}
    texts: dict[str, str] = {}

    for f in content_files:
        path = Path(f["path"])
        if f.get("size_bytes", 0) > _LARGE_FILE_BYTES:
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        shingles = _shingles(text)
        if len(shingles) < 10:
            continue  # too short to be meaningful
        signatures[f["path"]] = _minhash_signature(shingles)
        texts[f["path"]] = text

    # LSH bucketing: hash each band of the signature
    # Files that share at least one bucket are candidate pairs
    buckets: dict[tuple, list[str]] = {}
    for path_str, sig in signatures.items():
        for band_idx in range(NUM_BANDS):
            start = band_idx * ROWS_PER_BAND
            band = tuple(sig[start:start + ROWS_PER_BAND])
            key = (band_idx, band)
            buckets.setdefault(key, []).append(path_str)

    # Collect candidate pairs (bucket mates)
    candidate_pairs: set[tuple[str, str]] = set()
    for paths_in_bucket in buckets.values():
        if len(paths_in_bucket) < 2:
            continue
        for i in range(len(paths_in_bucket)):
            for j in range(i + 1, len(paths_in_bucket)):
                a, b = sorted([paths_in_bucket[i], paths_in_bucket[j]])
                candidate_pairs.add((a, b))

    findings: list[dict[str, Any]] = []
    duplicate_pairs = 0

    for a, b in sorted(candidate_pairs):
        sig_a = signatures.get(a)
        sig_b = signatures.get(b)
        if sig_a is None or sig_b is None:
            continue
        jaccard = _estimated_jaccard(sig_a, sig_b)
        if jaccard < SIMILARITY_THRESHOLD:
            continue

        duplicate_pairs += 1
        # Report on the file with more findings (the "secondary")
        findings.append({
            "job": "duplicate_detection",
            "severity": "WARNING",
            "confidence": "MEDIUM",
            "file": b,
            "message": (
                f"Estimated {jaccard:.0%} similarity with "
                f"{a} — consider merging or removing one"
            ),
            "auto_applicable": False,
        })

    return {
        "job": "duplicate_detection",
        "findings": findings,
        "summary": {
            "content_files_scanned": len(signatures),
            "candidate_pairs_checked": len(candidate_pairs),
            "duplicate_pairs": duplicate_pairs,
            "similarity_threshold": SIMILARITY_THRESHOLD,
            "findings_count": len(findings),
        },
    }
