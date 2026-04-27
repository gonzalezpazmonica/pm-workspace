#!/usr/bin/env python3
"""sentence-splitter.py — SE-075 Slice 2.

Spanish-aware sentence boundary splitter for long-form TTS chunking.
Re-implementation of the splitter pattern in voicebox `services/tts.py`
(MIT license); clean-room — no source code copied.

Usage:
  echo "Hola Sr. Pérez. ¿Qué tal?" | python3 sentence-splitter.py
  python3 sentence-splitter.py --file note.txt --max-chars 600

Reads stdin or --file, prints one chunk per line. A chunk is a single
sentence unless it exceeds --max-chars (default 600), in which case it
is split on the nearest comma/semicolon. Abbreviations preserved:
Sr., Sra., Sres., Sras., Sr.es., Dr., Dra., Drs., Lic., Ing., Prof.,
D., Dña., Vd., S.A., S.L., a.m., p.m., e.g., i.e., Ud., Uds., No.,
etc., aprox., depto., ext., núm., pág., págs.

Reference: SE-075 Slice 2 (docs/propuestas/SE-075-voicebox-adoption.md)
"""
from __future__ import annotations

import argparse
import re
import sys

# Abbreviations whose trailing period must NOT trigger a sentence break.
# Case-sensitive entries appear first; lowercase shortforms second.
SPANISH_ABBREV = [
    "Sr", "Sra", "Sres", "Sras", "Srta", "Srtas",
    "Dr", "Dra", "Drs", "Dras",
    "Lic", "Ing", "Prof", "Profa",
    "D", "Dña", "Da",
    "Vd", "Vds", "Ud", "Uds",
    "S.A", "S.L", "S.A.U", "S.L.U", "S.C",
    "a.m", "p.m", "e.g", "i.e",
    "etc", "aprox", "depto", "dpto", "ext",
    "núm", "no", "No", "pág", "págs", "vol", "vols",
    "izq", "der", "Av", "Avda", "Bvd", "C", "Ctra",
]

PLACEHOLDER = "␟"  # unit-separator-ish — extremely unlikely in user input


def _protect_abbreviations(text: str, abbrevs: list[str]) -> str:
    """Replace 'Sr.' with 'Sr<PLACEHOLDER>' so the period cannot break a sentence."""
    sorted_abbrevs = sorted(set(abbrevs), key=len, reverse=True)
    for ab in sorted_abbrevs:
        # Match abbrev followed by a period; don't require a word-boundary AFTER (numbers ok).
        pattern = re.compile(rf"(?<![A-Za-zÁÉÍÓÚÑáéíóúñ])({re.escape(ab)})\.")
        text = pattern.sub(rf"\1{PLACEHOLDER}", text)
    return text


def _restore(text: str) -> str:
    return text.replace(PLACEHOLDER, ".")


def _split_sentences(text: str) -> list[str]:
    text = _protect_abbreviations(text, SPANISH_ABBREV)
    # Split on terminal punctuation (.!?…) followed by whitespace OR end-of-string.
    # Keep the terminator with the preceding sentence.
    parts = re.split(r"(?<=[\.!\?…])\s+", text)
    return [_restore(p).strip() for p in parts if p.strip()]


def _split_long(sentence: str, max_chars: int) -> list[str]:
    """Break a sentence longer than max_chars at the nearest comma/semicolon."""
    if len(sentence) <= max_chars:
        return [sentence]
    out: list[str] = []
    remaining = sentence
    while len(remaining) > max_chars:
        # Look for ; , — within the budget, prefer rightmost.
        window = remaining[:max_chars]
        cut = max(window.rfind(";"), window.rfind(","), window.rfind(" — "))
        if cut < int(max_chars * 0.4):  # too early — fall back to last whitespace
            cut = window.rfind(" ")
            if cut < 1:
                cut = max_chars - 1  # hard break
        head = remaining[: cut + 1].strip()
        out.append(head)
        remaining = remaining[cut + 1 :].strip()
    if remaining:
        out.append(remaining)
    return out


def chunk(text: str, max_chars: int) -> list[str]:
    """Public entry-point: returns sentence chunks ≤ max_chars each."""
    chunks: list[str] = []
    for s in _split_sentences(text):
        chunks.extend(_split_long(s, max_chars))
    return chunks


def _cli() -> int:
    ap = argparse.ArgumentParser(prog="sentence-splitter.py")
    ap.add_argument("--file", help="Read from file instead of stdin")
    ap.add_argument("--max-chars", type=int, default=600,
                    help="Hard-cap per chunk before secondary split (default 600)")
    args = ap.parse_args()

    if args.file:
        with open(args.file, "r", encoding="utf-8") as f:
            text = f.read()
    else:
        text = sys.stdin.read()

    if not text.strip():
        return 0
    for c in chunk(text, args.max_chars):
        print(c)
    return 0


if __name__ == "__main__":
    sys.exit(_cli())
