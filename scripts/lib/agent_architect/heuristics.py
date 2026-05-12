"""Heuristics for monolith detection.

Each heuristic is a pure function: AgentAST + thresholds dict -> Signal.
Signals are qualitative: info | warn | alert.
Evidence is a short textual snippet from the agent.
"""
from __future__ import annotations

import re
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Callable, Dict, List, Optional

from .parser import AgentAST, Header


SignalLevel = str  # "info" | "warn" | "alert"


@dataclass
class Signal:
    name: str
    level: SignalLevel  # info | warn | alert
    value: float
    threshold_warn: float
    threshold_alert: float
    evidence: List[str] = field(default_factory=list)
    note: str = ""


# Imperative verbs that suggest a "responsibility" header.
# Bilingual: en + es. Detected as the first word of a header text (case-insensitive).
RESPONSIBILITY_VERBS = {
    "review", "fix", "test", "document", "analyze", "detect", "propose",
    "generate", "validate", "execute", "monitor", "report", "audit",
    "deploy", "build", "refactor", "translate", "summarize", "rank",
    "revisar", "corregir", "probar", "documentar", "analizar", "detectar",
    "proponer", "generar", "validar", "ejecutar", "monitorizar", "reportar",
    "auditar", "desplegar", "construir", "refactorizar", "traducir",
    "resumir", "clasificar",
}


def _level(value: float, warn: float, alert: float, *, higher_is_worse: bool = True) -> SignalLevel:
    if higher_is_worse:
        if value >= alert:
            return "alert"
        if value >= warn:
            return "warn"
        return "info"
    else:
        if value <= alert:
            return "alert"
        if value <= warn:
            return "warn"
        return "info"


def heuristic_length(ast: AgentAST, thresholds: Dict) -> Signal:
    cfg = thresholds.get("length", {"warn": 200, "alert": 400})
    if ast.is_orchestrator:
        cfg = {"warn": cfg["warn"] * 2, "alert": cfg["alert"] * 2}
    value = ast.line_count
    level = _level(value, cfg["warn"], cfg["alert"])
    return Signal(
        name="length",
        level=level,
        value=value,
        threshold_warn=cfg["warn"],
        threshold_alert=cfg["alert"],
        evidence=[f"file has {value} lines"],
    )


def heuristic_responsibilities(ast: AgentAST, thresholds: Dict) -> Signal:
    cfg = thresholds.get("responsibilities", {"warn": 3, "alert": 5})
    if ast.is_orchestrator:
        cfg = {"warn": cfg["warn"] * 2, "alert": cfg["alert"] * 2}
    distinct = set()
    evidence = []
    for h in ast.headers:
        first = h.text.split()[0].lower().rstrip(":") if h.text else ""
        first = re.sub(r"[^a-zA-Záéíóúñü]", "", first)
        if first in RESPONSIBILITY_VERBS:
            if first not in distinct:
                evidence.append(f"L{h.line_no}: {h.text}")
            distinct.add(first)
    value = len(distinct)
    level = _level(value, cfg["warn"], cfg["alert"])
    return Signal(
        name="responsibilities",
        level=level,
        value=value,
        threshold_warn=cfg["warn"],
        threshold_alert=cfg["alert"],
        evidence=evidence[:6],
        note=f"distinct verbs: {sorted(distinct)}",
    )


def heuristic_tools(ast: AgentAST, thresholds: Dict) -> Signal:
    cfg = thresholds.get("tools", {"warn": 6, "alert": 11})
    if ast.is_orchestrator:
        cfg = {"warn": cfg["warn"] * 2, "alert": cfg["alert"] * 2}
    value = len(ast.tools)
    level = _level(value, cfg["warn"], cfg["alert"])
    return Signal(
        name="tools",
        level=level,
        value=value,
        threshold_warn=cfg["warn"],
        threshold_alert=cfg["alert"],
        evidence=[f"declares tools: {', '.join(ast.tools) or '(none)'}"],
    )


# Pairs of mutually-contradictory phrases. Tuned conservatively.
CONTRADICTION_PAIRS = [
    (re.compile(r"\balways\b", re.I), re.compile(r"\bnever\b", re.I)),
    (re.compile(r"\bsiempre\b", re.I), re.compile(r"\bnunca\b", re.I)),
    (re.compile(r"\bmust not\b", re.I), re.compile(r"\bmust\b(?!\s+not)", re.I)),
    (re.compile(r"\bdebe(?:s|n)?\b(?!\s+no)", re.I), re.compile(r"\bno\s+debe(?:s|n)?\b", re.I)),
]


def _sentence_index(body: str, pos: int) -> int:
    """Return index of the sentence containing position `pos`.

    Sentences are delimited by `.`, `;`, `!`, `?` or newline. Coarse but stable
    enough to distinguish 'You always X. You never Y.' as two sentences.
    """
    return sum(1 for ch in body[:pos] if ch in ".;!?\n")


def heuristic_contradictions(ast: AgentAST, thresholds: Dict) -> Signal:
    cfg = thresholds.get("contradictions", {"warn": 1, "alert": 3})
    body = ast.body
    found_pairs = 0
    evidence = []
    for pos_re, neg_re in CONTRADICTION_PAIRS:
        pos_matches = list(pos_re.finditer(body))
        neg_matches = list(neg_re.finditer(body))
        if pos_matches and neg_matches:
            # Count if pos and neg appear in different sentences.
            pos_sents = {_sentence_index(body, m.start()) for m in pos_matches}
            neg_sents = {_sentence_index(body, m.start()) for m in neg_matches}
            if pos_sents - neg_sents and neg_sents - pos_sents:
                found_pairs += 1
                evidence.append(f"pair: {pos_re.pattern} vs {neg_re.pattern}")
    value = found_pairs
    level = _level(value, cfg["warn"], cfg["alert"])
    return Signal(
        name="contradictions",
        level=level,
        value=value,
        threshold_warn=cfg["warn"],
        threshold_alert=cfg["alert"],
        evidence=evidence,
    )


# "imagine you are X and also Y" style nesting.
ROLEPLAY_RE = re.compile(
    r"(imagine|act as|pretend|role[- ]?play|imagina|act\u00faa\s+como|finge|haz\s+de)",
    re.I,
)


def heuristic_roleplay_nesting(ast: AgentAST, thresholds: Dict) -> Signal:
    cfg = thresholds.get("roleplay_depth", {"warn": 1, "alert": 2})
    matches = ROLEPLAY_RE.findall(ast.body)
    # Each match is one "role". Depth is matches - 1 (one role is the natural agent role).
    depth = max(0, len(matches) - 1)
    level = _level(depth, cfg["warn"], cfg["alert"])
    return Signal(
        name="roleplay_depth",
        level=level,
        value=depth,
        threshold_warn=cfg["warn"],
        threshold_alert=cfg["alert"],
        evidence=[f"roleplay markers: {len(matches)}"] if matches else [],
    )


def heuristic_age(ast: AgentAST, thresholds: Dict) -> Signal:
    """Days since last filesystem modification.

    higher_is_worse=True: older means warn/alert.
    """
    cfg = thresholds.get("age_days", {"warn": 30, "alert": 180})
    try:
        mtime = ast.path.stat().st_mtime
        days = (time.time() - mtime) / 86400.0
    except OSError:
        days = 0.0
    level = _level(days, cfg["warn"], cfg["alert"])
    return Signal(
        name="age_days",
        level=level,
        value=round(days, 1),
        threshold_warn=cfg["warn"],
        threshold_alert=cfg["alert"],
        evidence=[f"mtime ~{round(days, 1)} days ago"],
    )


ALL_HEURISTICS: Dict[str, Callable[[AgentAST, Dict], Signal]] = {
    "length": heuristic_length,
    "responsibilities": heuristic_responsibilities,
    "tools": heuristic_tools,
    "contradictions": heuristic_contradictions,
    "roleplay_depth": heuristic_roleplay_nesting,
    "age_days": heuristic_age,
}
