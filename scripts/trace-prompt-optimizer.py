#!/usr/bin/env python3
"""
scripts/trace-prompt-optimizer.py — SPEC-044: Trace-to-Prompt Optimization

Analyzes a prompt text and detects issues that degrade agent performance.
Works as a standalone analyzer (no LLM required) using heuristic rules.

CLI:
    python3 scripts/trace-prompt-optimizer.py --prompt "texto del prompt"
    echo "prompt text" | python3 scripts/trace-prompt-optimizer.py

Output JSON:
    {
        "issues": [{"type": str, "severity": "high|medium|low", "text": str}],
        "score": 0-100,
        "suggestions": [str]
    }

Heuristics:
    - prompt > 2000 chars → "verbose"
    - same concept > 3 times → "repetitive"
    - contradictory instructions → "contradictory"
    - no examples when examples would help → "no_examples"
    - hedge words overuse → "hedging"
    - missing output format spec → "no_output_format"
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass, field
from typing import Any

# ── Issue severity weights (used in score calculation) ────────────────────────
SEVERITY_WEIGHTS: dict[str, int] = {
    "high":   20,
    "medium": 10,
    "low":     5,
}

# ── Contradiction pairs ────────────────────────────────────────────────────────
# Each tuple: (pattern_a, pattern_b) — if both found → contradiction
_CONTRADICTION_PAIRS: list[tuple[str, str]] = [
    (r"\bshort\b",           r"\bcomprehensive\b"),
    (r"\bbrief\b",           r"\bdetailed\b"),
    (r"\bconcise\b",         r"\bexhaustive\b"),
    (r"\bsimple\b",          r"\bcomplex\b"),
    (r"\bminimal\b",         r"\bthorough\b"),
    (r"\balways\b",          r"\bnever\b"),
    (r"\bmust\s+include\b",  r"\bdo\s+not\s+include\b"),
    (r"\bjson\s+only\b",     r"\bmarkdown\b"),
    (r"\bno\s+json\b",       r"\boutput\s+json\b"),
    (r"\bdo\s+not\s+use\b",  r"\byou\s+must\s+use\b"),
    (r"\bbullet\s+points\b", r"\bparagraph\s+form\b"),
]

# ── Hedge words (verbosity/uncertainty signals) ────────────────────────────────
_HEDGE_PATTERNS: list[str] = [
    r"\bmaybe\b", r"\bperhaps\b", r"\bsomewhat\b", r"\bkind\s+of\b",
    r"\bsort\s+of\b", r"\bmight\s+want\s+to\b", r"\bcould\s+consider\b",
    r"\bit\s+seems\b", r"\bif\s+possible\b", r"\bas\s+much\s+as\s+possible\b",
    r"\bgenerally\s+speaking\b", r"\bin\s+most\s+cases\b",
]

# ── Concept normalization helpers ──────────────────────────────────────────────
def _normalize(text: str) -> str:
    """Lowercase, strip punctuation, collapse whitespace."""
    text = text.lower()
    text = re.sub(r"[^\w\s]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def _extract_ngrams(words: list[str], n: int) -> list[str]:
    return [" ".join(words[i : i + n]) for i in range(len(words) - n + 1)]


@dataclass
class Issue:
    type: str
    severity: str
    text: str

    def to_dict(self) -> dict[str, str]:
        return {"type": self.type, "severity": self.severity, "text": self.text}


@dataclass
class AnalysisResult:
    issues: list[Issue] = field(default_factory=list)
    score: int = 100
    suggestions: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "issues": [i.to_dict() for i in self.issues],
            "score": self.score,
            "suggestions": self.suggestions,
        }


# ── Detectors ──────────────────────────────────────────────────────────────────

def detect_verbose(prompt: str) -> Issue | None:
    """prompt > 2000 chars is considered verbose."""
    if len(prompt) > 2000:
        chars = len(prompt)
        return Issue(
            type="verbose",
            severity="medium",
            text=f"Prompt is {chars} chars (threshold: 2000). Long prompts increase token cost and reduce model focus.",
        )
    return None


def detect_repetitive(prompt: str) -> list[Issue]:
    """Same concept repeated > 3 times → repetitive."""
    issues: list[Issue] = []
    normalized = _normalize(prompt)
    words = normalized.split()

    # Check 2-grams and 3-grams for repetitions
    for n in (2, 3):
        ngrams = _extract_ngrams(words, n)
        counts = Counter(ngrams)
        for ngram, count in counts.items():
            # Skip trivial connectors
            if all(w in {"the", "a", "an", "of", "in", "to", "and", "or", "is", "are", "you", "your"} for w in ngram.split()):
                continue
            if count > 3:
                issues.append(Issue(
                    type="repetitive",
                    severity="medium",
                    text=f'Concept "{ngram}" appears {count} times. Repetition adds tokens without clarity.',
                ))
    # Also check individual meaningful keywords
    # Filter stopwords
    _STOPWORDS = {
        "the", "a", "an", "of", "in", "to", "and", "or", "is", "are",
        "you", "your", "it", "this", "that", "be", "as", "at", "by",
        "for", "on", "with", "not", "do", "can", "will", "should",
        "must", "may", "have", "has", "had", "but", "if", "when",
    }
    meaningful = [w for w in words if len(w) > 4 and w not in _STOPWORDS]
    word_counts = Counter(meaningful)
    for word, count in word_counts.items():
        if count > 4:
            issues.append(Issue(
                type="repetitive",
                severity="low",
                text=f'Word "{word}" appears {count} times. Consider consolidating.',
            ))
    return issues


def detect_contradictions(prompt: str) -> list[Issue]:
    """Detect contradictory instruction pairs."""
    issues: list[Issue] = []
    lowered = prompt.lower()
    for pat_a, pat_b in _CONTRADICTION_PAIRS:
        if re.search(pat_a, lowered) and re.search(pat_b, lowered):
            # Extract the actual matched terms for reporting
            m_a = re.search(pat_a, lowered)
            m_b = re.search(pat_b, lowered)
            term_a = m_a.group(0) if m_a else pat_a
            term_b = m_b.group(0) if m_b else pat_b
            issues.append(Issue(
                type="contradictory",
                severity="high",
                text=f'Contradictory instructions detected: "{term_a}" conflicts with "{term_b}".',
            ))
    return issues


def detect_no_examples(prompt: str) -> Issue | None:
    """Prompts > 500 chars asking for structured output without examples."""
    if len(prompt) < 500:
        return None
    lowered = prompt.lower()
    # Signals that examples would help
    needs_example = any(re.search(p, lowered) for p in [
        r"\bjson\b", r"\bformat\b", r"\bstructure\b",
        r"\boutput\b", r"\bresponse\b", r"\btemplate\b",
    ])
    has_example = any(re.search(p, lowered) for p in [
        r"\bexample\b", r"\bfor\s+instance\b", r"\be\.g\.\b",
        r"\bsample\b", r"\blike\s+this\b", r"```",
    ])
    if needs_example and not has_example:
        return Issue(
            type="no_examples",
            severity="medium",
            text="Prompt requests structured output but provides no examples. Add a sample to reduce ambiguity.",
        )
    return None


def detect_hedging(prompt: str) -> Issue | None:
    """Overuse of hedge words indicates uncertain instructions."""
    count = 0
    for pat in _HEDGE_PATTERNS:
        count += len(re.findall(pat, prompt, re.IGNORECASE))
    if count >= 4:
        return Issue(
            type="hedging",
            severity="low",
            text=f"Found {count} hedge phrases (maybe, perhaps, if possible…). Replace with direct instructions.",
        )
    return None


def detect_no_output_format(prompt: str) -> Issue | None:
    """Long prompt with no output format specification."""
    if len(prompt) < 300:
        return None
    lowered = prompt.lower()
    has_format = any(re.search(p, lowered) for p in [
        r"\boutput\s+(as|in|format)\b", r"\bresponse\s+format\b",
        r"\breturn\s+(a\s+)?json\b", r"\brespond\s+(in|with)\b",
        r"```", r"\byaml\b", r"\bmarkdown\b", r"\bplain\s+text\b",
    ])
    if not has_format:
        return Issue(
            type="no_output_format",
            severity="low",
            text="Prompt does not specify output format. Add 'Output as JSON' or similar to reduce hallucinations.",
        )
    return None


# ── Score calculation ──────────────────────────────────────────────────────────

def compute_score(issues: list[Issue]) -> int:
    """Start at 100, deduct points per issue severity."""
    penalty = sum(SEVERITY_WEIGHTS.get(i.severity, 5) for i in issues)
    return max(0, 100 - penalty)


# ── Suggestion builder ─────────────────────────────────────────────────────────

def build_suggestions(issues: list[Issue]) -> list[str]:
    """Map issue types to actionable suggestions (deduped)."""
    seen: set[str] = set()
    suggestions: list[str] = []

    _SUGGESTION_MAP: dict[str, str] = {
        "verbose": "Split the prompt into a system prompt + user prompt. Move context to system, keep instruction in user.",
        "repetitive": "Consolidate repeated concepts into a single authoritative statement.",
        "contradictory": "Remove conflicting instructions. Decide one behavior and state it once clearly.",
        "no_examples": "Add 1-2 concrete input/output examples using triple-backtick code blocks.",
        "hedging": "Replace hedge phrases with direct imperatives: 'do X' instead of 'maybe do X if possible'.",
        "no_output_format": "Add an explicit output format section: 'Output: JSON object with keys: ...'.",
    }

    for issue in issues:
        suggestion = _SUGGESTION_MAP.get(issue.type)
        if suggestion and suggestion not in seen:
            suggestions.append(suggestion)
            seen.add(suggestion)

    return suggestions


# ── Main analysis entry point ─────────────────────────────────────────────────

def analyze(prompt: str) -> AnalysisResult:
    """Run all detectors and return AnalysisResult."""
    issues: list[Issue] = []

    # Run all detectors
    if (issue := detect_verbose(prompt)):
        issues.append(issue)

    issues.extend(detect_repetitive(prompt))
    issues.extend(detect_contradictions(prompt))

    if (issue := detect_no_examples(prompt)):
        issues.append(issue)
    if (issue := detect_hedging(prompt)):
        issues.append(issue)
    if (issue := detect_no_output_format(prompt)):
        issues.append(issue)

    score = compute_score(issues)
    suggestions = build_suggestions(issues)

    return AnalysisResult(issues=issues, score=score, suggestions=suggestions)


# ── CLI ───────────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="trace-prompt-optimizer.py",
        description="SPEC-044: Analyze a prompt for optimization opportunities",
    )
    p.add_argument(
        "--prompt",
        default=None,
        metavar="TEXT",
        help="Prompt text to analyze (or read from stdin)",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.prompt:
        prompt_text = args.prompt
    elif not sys.stdin.isatty():
        prompt_text = sys.stdin.read()
    else:
        parser.print_help()
        return 1

    result = analyze(prompt_text)
    print(json.dumps(result.to_dict(), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
