#!/usr/bin/env python3
"""scripts/semantic-fault-handlers.py — SPEC-059: Semantic Fault Handlers

Classifies agent errors into semantic categories and returns structured
recovery recommendations.

CLI:
    python3 scripts/semantic-fault-handlers.py \
        --error "timeout after 30s" [--context "additional context"]

Output JSON:
    {
        "category": "TRANSIENT",
        "confidence": 0.92,
        "suggested_handler": "retry",
        "retry_strategy": "backoff"
    }
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass


# ── Error categories ──────────────────────────────────────────────────────────

CATEGORIES = frozenset({
    "FORMAT",
    "SCOPE",
    "VALIDATION",
    "TRANSIENT",
    "CAPACITY",
    "LOGIC",
})

# category → (suggested_handler, retry_strategy)
CATEGORY_DEFAULTS: dict[str, tuple[str, str]] = {
    "FORMAT":     ("regenerate", "immediate"),
    "SCOPE":      ("decompose",  "immediate"),
    "VALIDATION": ("regenerate", "immediate"),
    "TRANSIENT":  ("retry",      "backoff"),
    "CAPACITY":   ("decompose",  "none"),
    "LOGIC":      ("escalate",   "none"),
}

# ── Keyword patterns per category ─────────────────────────────────────────────
# Each entry: (pattern, weight, category)
# Patterns are case-insensitive. Higher weight = stronger signal.
_RULES: list[tuple[re.Pattern, float, str]] = []

_RAW_RULES: list[tuple[str, float, str]] = [
    # TRANSIENT — network/time issues
    (r"\btimeout\b",                        1.0, "TRANSIENT"),
    (r"\btimed?\s*out\b",                   1.0, "TRANSIENT"),
    (r"\brate[\s_-]?limit\b",              0.9, "TRANSIENT"),
    (r"\b429\b",                            0.8, "TRANSIENT"),
    (r"\bnetwork\s+(error|failure|down)\b", 0.9, "TRANSIENT"),
    (r"\bconnection\s+(refused|reset|lost|error)\b", 0.9, "TRANSIENT"),
    (r"\bservice\s+unavailable\b",          0.9, "TRANSIENT"),
    (r"\btemporarily\s+unavailable\b",      0.8, "TRANSIENT"),
    (r"\b503\b",                            0.7, "TRANSIENT"),
    (r"\bretry\s+later\b",                  0.7, "TRANSIENT"),

    # CAPACITY — context / token exhaustion
    (r"\bcontext\s+window\b",               1.0, "CAPACITY"),
    (r"\bcontext\s+(exceeded|exhausted|full|overflow)\b", 1.0, "CAPACITY"),
    (r"\btoken\s*(limit|budget)\s*(exceeded|reached|overflow)\b", 1.0, "CAPACITY"),
    (r"\bmax\s+tokens?\b",                  0.8, "CAPACITY"),
    (r"\bprompt\s+too\s+long\b",            0.9, "CAPACITY"),
    (r"\boutput\s+truncated\b",             0.7, "CAPACITY"),
    (r"\bcontext\s+length\b",              0.8, "CAPACITY"),

    # FORMAT — output structure problems
    (r"\bmissing\s+required\s+field\b",     1.0, "FORMAT"),
    (r"\binvalid\s+(json|yaml|xml|format)\b", 0.9, "FORMAT"),
    (r"\bparse\s+(error|fail|failed)\b",    0.8, "FORMAT"),
    (r"\bexpected\s+json\b",                0.9, "FORMAT"),
    (r"\bmalformed\b",                      0.7, "FORMAT"),
    (r"\bdeserialization\s+error\b",        0.9, "FORMAT"),
    (r"\bschema\s+validation\s+(fail|error)\b", 0.8, "FORMAT"),
    (r"\bwrong\s+(output|format|structure)\b", 0.8, "FORMAT"),
    (r"\bexpected\s+(field|key|property)\b", 0.7, "FORMAT"),
    (r"\bmissing\s+(key|field|attribute)\b", 0.8, "FORMAT"),

    # SCOPE — doing too much or too little
    (r"\b(instead\s+of\s+\d+|\d+\s+files?\s+instead)\b", 0.9, "SCOPE"),
    (r"\bmodified\s+\d+\s+files?\s+instead\s+of\s+\d+\b", 1.0, "SCOPE"),
    (r"\bchanged\s+\d+\s+files?\s+instead\s+of\s+\d+\b", 1.0, "SCOPE"),
    (r"\bscope\s+(violation|exceeded|overreach)\b", 1.0, "SCOPE"),
    (r"\bunauthorized\s+(action|modification|access)\b", 0.8, "SCOPE"),
    (r"\boutside\s+(allowed|spec|scope)\b", 0.9, "SCOPE"),
    (r"\btouched\s+files?\s+outside\b",     0.9, "SCOPE"),
    (r"\bexceed(ed)?\s+(scope|task|boundary)\b", 0.8, "SCOPE"),

    # VALIDATION — ACs, tests, lint failures
    (r"\bac[\s_-]?\d+\s+(fail|fails|failed|failing)\b", 1.0, "VALIDATION"),
    (r"\bacceptance\s+criteria\s+(fail|not\s+met)\b", 1.0, "VALIDATION"),
    (r"\btask\s+completed\s+but\b",         0.8, "VALIDATION"),
    (r"\btests?\s+(fail|failed|failing)\b", 0.8, "VALIDATION"),
    (r"\blint\s+(error|fail|failed)\b",     0.7, "VALIDATION"),
    (r"\bverification\s+(fail|failed)\b",   0.9, "VALIDATION"),
    (r"\bvalidation\s+(fail|failed|error)\b", 0.9, "VALIDATION"),
    (r"\bquality\s+gate\s+(fail|failed)\b", 0.8, "VALIDATION"),
    (r"\bcriteria\s+not\s+met\b",           0.9, "VALIDATION"),
    (r"\bspec\s+not\s+satisfied\b",         0.8, "VALIDATION"),

    # LOGIC — incorrect implementation
    (r"\bincorrect\s+(algorithm|logic|implementation)\b", 1.0, "LOGIC"),
    (r"\bwrong\s+(algorithm|logic|result|output)\b", 0.9, "LOGIC"),
    (r"\bsemantic\s+error\b",               0.9, "LOGIC"),
    (r"\bbusiness\s+logic\s+(error|incorrect|wrong)\b", 0.9, "LOGIC"),
    (r"\binfinite\s+loop\b",                0.8, "LOGIC"),
    (r"\bstack\s+overflow\b",               0.7, "LOGIC"),
    (r"\bnull\s+(pointer|reference)\s+exception\b", 0.6, "LOGIC"),
]

for _raw_pat, _weight, _cat in _RAW_RULES:
    _RULES.append((re.compile(_raw_pat, re.IGNORECASE | re.MULTILINE), _weight, _cat))


# ── Classification ─────────────────────────────────────────────────────────────

@dataclass
class ClassificationResult:
    category: str
    confidence: float
    suggested_handler: str
    retry_strategy: str

    def to_dict(self) -> dict:
        return {
            "category": self.category,
            "confidence": round(self.confidence, 4),
            "suggested_handler": self.suggested_handler,
            "retry_strategy": self.retry_strategy,
        }


def classify(error_text: str, context: str = "") -> ClassificationResult:
    """Classify error_text into a semantic category with confidence score."""
    combined = f"{error_text} {context}".strip()

    # Accumulate scores per category
    scores: dict[str, float] = {cat: 0.0 for cat in CATEGORIES}

    for pattern, weight, category in _RULES:
        if pattern.search(combined):
            scores[category] += weight

    total = sum(scores.values())

    if total == 0.0:
        # Default to LOGIC when no signal detected
        return ClassificationResult(
            category="LOGIC",
            confidence=0.3,
            suggested_handler=CATEGORY_DEFAULTS["LOGIC"][0],
            retry_strategy=CATEGORY_DEFAULTS["LOGIC"][1],
        )

    # Pick highest-scoring category
    best_cat = max(scores, key=lambda c: scores[c])
    raw_confidence = scores[best_cat] / total

    # Clamp to [0, 1]
    confidence = min(1.0, max(0.0, raw_confidence))

    handler, strategy = CATEGORY_DEFAULTS[best_cat]
    return ClassificationResult(
        category=best_cat,
        confidence=confidence,
        suggested_handler=handler,
        retry_strategy=strategy,
    )


# ── CLI ───────────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="semantic-fault-handlers.py",
        description="SPEC-059: Classify agent errors into semantic categories",
    )
    p.add_argument(
        "--error",
        required=True,
        metavar="TEXT",
        help="Error text to classify",
    )
    p.add_argument(
        "--context",
        default="",
        metavar="TEXT",
        help="Additional context about the error (optional)",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    result = classify(args.error, args.context)
    print(json.dumps(result.to_dict(), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
