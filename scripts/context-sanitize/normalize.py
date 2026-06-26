#!/usr/bin/env python3
"""normalize.py — SPEC-193 Capa A, Componente 1.

NFKC canonicalization + invisible-char strip + bidi-control reject +
homoglyph score. Output JSON con campos normalize, original, transformations,
homoglyph_score, bidi_present.

CLI:
    python3 normalize.py --text TEXT --json
    echo TEXT | python3 normalize.py --stdin --json
"""
from __future__ import annotations

import argparse
import json
import sys
import unicodedata
from typing import Any

# ── Character sets ──────────────────────────────────────────────────────────

INVISIBLE_CHARS = frozenset(
    "\u200b"  # zero-width space
    "\u200c"  # zero-width non-joiner
    "\u200d"  # zero-width joiner
    "\u2060"  # word joiner
    "\ufeff"  # BOM / zero-width no-break space
    "\u00ad"  # soft hyphen
)

BIDI_CONTROLS = frozenset(
    "\u202a"  # LRE
    "\u202b"  # RLE
    "\u202c"  # PDF
    "\u202d"  # LRO
    "\u202e"  # RLO
    "\u2066"  # LRI
    "\u2067"  # RLI
    "\u2068"  # FSI
    "\u2069"  # PDI
)

TAGS_RANGE_START = 0xE0000
TAGS_RANGE_END   = 0xE007F

SOFT_HYPHEN = "\u00ad"


def _has_invisible(text: str) -> bool:
    return any(c in INVISIBLE_CHARS for c in text)


def _has_tags(text: str) -> bool:
    return any(TAGS_RANGE_START <= ord(c) <= TAGS_RANGE_END for c in text)


def _has_soft_hyphen_in_alpha(text: str) -> bool:
    """Soft hyphen inside a run of alpha characters — likely adversarial."""
    for i, c in enumerate(text):
        if c == SOFT_HYPHEN:
            left  = text[i - 1] if i > 0 else ""
            right = text[i + 1] if i + 1 < len(text) else ""
            if (left and left.isalpha()) and (right and right.isalpha()):
                return True
    return False


# ── Homoglyph score (imported from homoglyph_detect) ─────────────────────────

def _compute_homoglyph_score(text: str) -> int:
    """Compute homoglyph score on the original (pre-normalized) text.

    Delegates to homoglyph_detect module if available in the same directory,
    otherwise uses an embedded implementation to keep this file self-contained.
    """
    try:
        import importlib.util
        from pathlib import Path
        spec = importlib.util.spec_from_file_location(
            "homoglyph_detect",
            Path(__file__).parent / "homoglyph-detect.py",
        )
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod.score(text)
    except Exception:
        # Fallback: inline implementation (subset)
        return _score_inline(text)


def _score_inline(text: str) -> int:
    """Minimal inline scorer used when homoglyph-detect.py is unavailable."""
    score = 0
    has_bidi = any(c in BIDI_CONTROLS for c in text)
    if has_bidi:
        score += 50

    has_tags = any(TAGS_RANGE_START <= ord(c) <= TAGS_RANGE_END for c in text)
    if has_tags:
        score += 50

    # Count zero-width chars
    zw_count = sum(1 for c in text if c in (
        "\u200b", "\u200c", "\u200d", "\u2060"
    ))
    score += zw_count * 15

    # Soft hyphen in alpha context
    if _has_soft_hyphen_in_alpha(text):
        score += 20

    # Word-level script mixing (Latin + Cyrillic / Greek)
    for word in _split_words(text):
        if len(word) < 2:
            continue
        has_latin    = any(_is_latin(c)    for c in word)
        has_cyrillic = any(_is_cyrillic(c) for c in word)
        has_greek    = any(_is_greek(c)    for c in word)
        has_math     = any(_is_math_alpha(c) for c in word)
        if has_latin and has_cyrillic:
            score += 30
        if has_latin and has_greek:
            score += 25
        if has_math:
            score += 20

    return min(100, score)


def _split_words(text: str) -> list[str]:
    """Split on non-letter boundaries, returning runs of unicode letters."""
    words: list[str] = []
    current: list[str] = []
    for c in text:
        if unicodedata.category(c).startswith("L"):
            current.append(c)
        else:
            if current:
                words.append("".join(current))
                current = []
    if current:
        words.append("".join(current))
    return words


def _is_latin(c: str) -> bool:
    name = unicodedata.name(c, "")
    return "LATIN" in name


def _is_cyrillic(c: str) -> bool:
    name = unicodedata.name(c, "")
    return "CYRILLIC" in name


def _is_greek(c: str) -> bool:
    name = unicodedata.name(c, "")
    return "GREEK" in name


def _is_math_alpha(c: str) -> bool:
    o = ord(c)
    return 0x1D400 <= o <= 0x1D7FF


# ── Main normalize function ─────────────────────────────────────────────────

def normalize(text: str) -> dict[str, Any]:
    """Normalize text and return analysis dict.

    Returns:
        {
            normalized:        str   — NFKC output, invisible/tags stripped,
            original:          str   — input unchanged,
            transformations:   list  — list of applied transforms,
            homoglyph_score:   int   — 0-100, computed on original,
            bidi_present:      bool  — True if any bidi control char found,
        }
    """
    transformations: list[str] = []

    # Detect bidi before any stripping (on original)
    bidi_present = any(c in BIDI_CONTROLS for c in text)
    if bidi_present:
        transformations.append("bidi_rejected")

    # Step 1: strip invisible chars
    cleaned = "".join(c for c in text if c not in INVISIBLE_CHARS)
    if cleaned != text:
        transformations.append("invisible_stripped")

    # Step 2: strip Unicode tags block
    before_tags = cleaned
    cleaned = "".join(
        c for c in cleaned
        if not (TAGS_RANGE_START <= ord(c) <= TAGS_RANGE_END)
    )
    if cleaned != before_tags:
        transformations.append("unicode_tags_stripped")

    # Step 3: strip bidi controls from the cleaned string
    before_bidi = cleaned
    cleaned = "".join(c for c in cleaned if c not in BIDI_CONTROLS)
    if cleaned != before_bidi:
        transformations.append("bidi_stripped")

    # Step 4: NFKC normalization
    nfkc = unicodedata.normalize("NFKC", cleaned)
    if nfkc != cleaned:
        transformations.append("nfkc_normalized")

    # Compute score on original (captures the attack attempt)
    homoglyph_score = _compute_homoglyph_score(text)

    return {
        "normalized":      nfkc,
        "original":        text,
        "transformations": transformations,
        "homoglyph_score": homoglyph_score,
        "bidi_present":    bidi_present,
    }


# ── CLI ─────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="SPEC-193 Capa A: normalize text input"
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--text", help="Text to normalize")
    group.add_argument("--stdin", action="store_true", help="Read text from stdin")
    parser.add_argument("--json", action="store_true", help="Output JSON (required)")
    args = parser.parse_args()

    if args.stdin:
        text = sys.stdin.read()
    elif args.text is not None:
        text = args.text
    else:
        parser.error("provide --text TEXT or --stdin")

    result = normalize(text)

    if args.json:
        print(json.dumps(result, ensure_ascii=False))
    else:
        print(result)


if __name__ == "__main__":
    main()
