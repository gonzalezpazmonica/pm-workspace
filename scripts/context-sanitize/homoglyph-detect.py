#!/usr/bin/env python3
"""homoglyph-detect.py — SPEC-193 Capa A, Componente 2.

Detects Latin <-> Cyrillic / Greek / Mathematical script mixing.
Score 0-100 using weight table from spec.

CLI:
    python3 homoglyph-detect.py --text TEXT
    python3 homoglyph-detect.py --text TEXT --json
"""
from __future__ import annotations

import argparse
import json
import sys
import unicodedata

# ── Weight table (SPEC-193 §Design §Capa A) ─────────────────────────────────

# Bidi controls
BIDI_CONTROLS = frozenset(
    "\u202a\u202b\u202c\u202d\u202e"  # LRE, RLE, PDF, LRO, RLO
    "\u2066\u2067\u2068\u2069"        # LRI, RLI, FSI, PDI
)
BIDI_WEIGHT = 50   # per occurrence; also sets bidi_present

# Unicode Tags block U+E0000-U+E007F — always adversarial
TAGS_START = 0xE0000
TAGS_END   = 0xE007F
TAGS_WEIGHT = 50  # per character (capped at 100 total)

# Zero-width chars (not including soft hyphen)
ZW_CHARS = frozenset("\u200b\u200c\u200d\u2060")
ZW_WEIGHT = 30  # per character — zero-width in plain text is unambiguously adversarial

# Soft hyphen U+00AD inside alpha context
SOFT_HYPHEN = "\u00ad"
SOFT_HYPHEN_WEIGHT = 30  # clear adversarial signal in alpha sequences

# Word-level script mixing weights (per word)
LATIN_CYRILLIC_WEIGHT = 30
LATIN_GREEK_WEIGHT    = 30  # Greek confusables equally dangerous as Cyrillic
MATH_ALPHA_WEIGHT     = 30  # Mathematical Alphanumeric U+1D400-U+1D7FF, per occurrence


# ── Unicode category helpers ─────────────────────────────────────────────────

def _get_unicode_name(c: str) -> str:
    try:
        return unicodedata.name(c, "")
    except Exception:
        return ""


def _is_latin(c: str) -> bool:
    return "LATIN" in _get_unicode_name(c)


def _is_cyrillic(c: str) -> bool:
    return "CYRILLIC" in _get_unicode_name(c)


def _is_greek(c: str) -> bool:
    return "GREEK" in _get_unicode_name(c)


def _is_math_alpha(c: str) -> bool:
    return 0x1D400 <= ord(c) <= 0x1D7FF


def _is_letter(c: str) -> bool:
    return unicodedata.category(c).startswith("L")


def _split_words(text: str) -> list[str]:
    """Return runs of Unicode letters, split on non-letter codepoints."""
    words: list[str] = []
    buf: list[str] = []
    for c in text:
        if _is_letter(c):
            buf.append(c)
        else:
            if buf:
                words.append("".join(buf))
                buf = []
    if buf:
        words.append("".join(buf))
    return words


# ── Core scorer ─────────────────────────────────────────────────────────────

def score(text: str) -> int:
    """Return homoglyph risk score 0-100 for *text*.

    Score is computed on the original text (before any normalization) to
    capture the attack attempt.
    """
    total = 0
    evidence: list[str] = []

    # ── Bidi controls
    bidi_count = sum(1 for c in text if c in BIDI_CONTROLS)
    if bidi_count:
        total += BIDI_WEIGHT  # one flat penalty regardless of count
        evidence.append(f"bidi_controls:{bidi_count}")

    # ── Unicode Tags block
    tag_count = sum(1 for c in text if TAGS_START <= ord(c) <= TAGS_END)
    if tag_count:
        total += min(TAGS_WEIGHT * tag_count, 50)  # cap contribution to 50
        evidence.append(f"unicode_tags:{tag_count}")

    # ── Zero-width chars
    zw_count = sum(1 for c in text if c in ZW_CHARS)
    if zw_count:
        total += zw_count * ZW_WEIGHT
        evidence.append(f"zero_width:{zw_count}")

    # ── Soft hyphen inside alpha context
    for i, c in enumerate(text):
        if c == SOFT_HYPHEN:
            left  = text[i - 1] if i > 0 else ""
            right = text[i + 1] if i + 1 < len(text) else ""
            if left and left.isalpha() and right and right.isalpha():
                total += SOFT_HYPHEN_WEIGHT
                evidence.append("soft_hyphen_in_alpha")
                break  # one penalty per text

    # ── Mathematical Alphanumeric symbols
    math_count = sum(1 for c in text if _is_math_alpha(c))
    if math_count:
        total += math_count * MATH_ALPHA_WEIGHT
        evidence.append(f"math_alpha:{math_count}")

    # ── Word-level script mixing
    mixed_latin_cyrillic = 0
    mixed_latin_greek    = 0

    for word in _split_words(text):
        if len(word) < 2:
            continue
        has_latin    = any(_is_latin(c)    for c in word)
        has_cyrillic = any(_is_cyrillic(c) for c in word)
        has_greek    = any(_is_greek(c)    for c in word)

        if has_latin and has_cyrillic:
            mixed_latin_cyrillic += 1
        if has_latin and has_greek:
            mixed_latin_greek += 1

    if mixed_latin_cyrillic:
        total += mixed_latin_cyrillic * LATIN_CYRILLIC_WEIGHT
        evidence.append(f"latin_cyrillic_mixing:{mixed_latin_cyrillic}_words")
    if mixed_latin_greek:
        total += mixed_latin_greek * LATIN_GREEK_WEIGHT
        evidence.append(f"latin_greek_mixing:{mixed_latin_greek}_words")

    return min(100, total)


def analyze(text: str) -> dict:
    """Return full analysis dict including score and evidence."""
    s = score(text)

    # Re-collect evidence (fast dup of score logic with evidence)
    ev: list[str] = []

    bidi_count = sum(1 for c in text if c in BIDI_CONTROLS)
    if bidi_count:
        ev.append(f"bidi_controls:{bidi_count}")

    tag_count = sum(1 for c in text if TAGS_START <= ord(c) <= TAGS_END)
    if tag_count:
        ev.append(f"unicode_tags:{tag_count}")

    zw_count = sum(1 for c in text if c in ZW_CHARS)
    if zw_count:
        ev.append(f"zero_width:{zw_count}")

    for i, c in enumerate(text):
        if c == SOFT_HYPHEN:
            left  = text[i - 1] if i > 0 else ""
            right = text[i + 1] if i + 1 < len(text) else ""
            if left and left.isalpha() and right and right.isalpha():
                ev.append("soft_hyphen_in_alpha")
                break

    math_count = sum(1 for c in text if _is_math_alpha(c))
    if math_count:
        ev.append(f"math_alpha:{math_count}")

    for word in _split_words(text):
        if len(word) < 2:
            continue
        has_latin    = any(_is_latin(c)    for c in word)
        has_cyrillic = any(_is_cyrillic(c) for c in word)
        has_greek    = any(_is_greek(c)    for c in word)
        if has_latin and has_cyrillic:
            ev.append(f"word_latin_cyrillic:{word!r}")
        if has_latin and has_greek:
            ev.append(f"word_latin_greek:{word!r}")

    return {
        "score":    s,
        "evidence": ev,
        "risk":     "block" if s >= 70 else ("warn" if s >= 30 else "pass"),
    }


# ── CLI ─────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="SPEC-193 Capa A: homoglyph risk scorer"
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--text", help="Text to analyze")
    group.add_argument("--stdin", action="store_true", help="Read from stdin")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    args = parser.parse_args()

    if args.stdin:
        text = sys.stdin.read()
    elif args.text is not None:
        text = args.text
    else:
        parser.error("provide --text TEXT or --stdin")

    result = analyze(text)

    if args.json:
        print(json.dumps(result, ensure_ascii=False))
    else:
        print(f"score={result['score']} risk={result['risk']}")
        if result["evidence"]:
            print("evidence:", ", ".join(result["evidence"]))


if __name__ == "__main__":
    main()
