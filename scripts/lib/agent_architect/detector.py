"""Detector — runs all heuristics on an AgentAST and aggregates signals.

The detector loads thresholds from YAML, executes every heuristic, and
returns an AnalysisResult. A separate `aggregate` function builds the
ranking from a list of analyses.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional

import yaml

from .heuristics import ALL_HEURISTICS, Signal
from .parser import AgentAST, parse_agent


DEFAULT_THRESHOLDS = {
    "length":          {"warn": 200, "alert": 400},
    "responsibilities":{"warn": 3,   "alert": 5},
    "tools":           {"warn": 6,   "alert": 11},
    "contradictions":  {"warn": 1,   "alert": 3},
    "roleplay_depth":  {"warn": 1,   "alert": 2},
    "age_days":        {"warn": 30,  "alert": 180},
    # Whitelist: agents matched here see thresholds doubled (orchestrator-style).
    "orchestrator_whitelist": [],
}


@dataclass
class AnalysisResult:
    agent_id: str
    path: str
    signals: List[Signal] = field(default_factory=list)
    parse_errors: List[str] = field(default_factory=list)

    @property
    def alerts(self) -> int:
        return sum(1 for s in self.signals if s.level == "alert")

    @property
    def warns(self) -> int:
        return sum(1 for s in self.signals if s.level == "warn")

    @property
    def is_candidate(self) -> bool:
        """≥ 2 alerts -> candidate for decomposition (per spec §2.1)."""
        return self.alerts >= 2

    def to_dict(self) -> dict:
        return {
            "agent_id": self.agent_id,
            "path": self.path,
            "alerts": self.alerts,
            "warns": self.warns,
            "is_candidate": self.is_candidate,
            "parse_errors": self.parse_errors,
            "signals": [
                {
                    "name": s.name,
                    "level": s.level,
                    "value": s.value,
                    "warn": s.threshold_warn,
                    "alert": s.threshold_alert,
                    "evidence": s.evidence,
                    "note": s.note,
                }
                for s in self.signals
            ],
        }


def load_thresholds(path: Optional[Path] = None) -> Dict:
    """Load thresholds YAML; merge over defaults. Missing file -> defaults."""
    cfg = {k: (dict(v) if isinstance(v, dict) else list(v)) for k, v in DEFAULT_THRESHOLDS.items()}
    if path is None:
        candidate = Path(".opencode/agent-architect-thresholds.yaml")
        if candidate.exists():
            path = candidate
    if path is None or not Path(path).exists():
        return cfg
    try:
        loaded = yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}
    except yaml.YAMLError:
        return cfg
    if not isinstance(loaded, dict):
        return cfg
    for k, v in loaded.items():
        if k == "orchestrator_whitelist" and isinstance(v, list):
            cfg[k] = list(v)
        elif isinstance(v, dict) and k in cfg and isinstance(cfg[k], dict):
            cfg[k].update({kk: vv for kk, vv in v.items() if kk in ("warn", "alert")})
    return cfg


def analyze(ast: AgentAST, thresholds: Optional[Dict] = None) -> AnalysisResult:
    cfg = thresholds if thresholds is not None else load_thresholds()
    # Apply orchestrator whitelist as a frontmatter override.
    whitelist = set(cfg.get("orchestrator_whitelist") or [])
    if ast.name in whitelist or ast.path.stem in whitelist:
        # Force orchestrator-mode behavior in heuristics.
        ast.frontmatter = dict(ast.frontmatter)
        ast.frontmatter["kind"] = "orchestrator"

    result = AnalysisResult(
        agent_id=ast.name or ast.path.stem,
        path=str(ast.path),
        parse_errors=list(ast.parse_errors),
    )
    for name, fn in ALL_HEURISTICS.items():
        try:
            sig = fn(ast, cfg)
            result.signals.append(sig)
        except Exception as e:  # noqa: BLE001 — heuristics are user-extensible
            result.parse_errors.append(f"heuristic {name} failed: {e}")
    return result


def analyze_path(path: Path, thresholds: Optional[Dict] = None) -> AnalysisResult:
    return analyze(parse_agent(path), thresholds)


def aggregate(results: List[AnalysisResult]) -> List[AnalysisResult]:
    """Sort: candidates first (most alerts desc), then by warns desc, then by id."""
    return sorted(
        results,
        key=lambda r: (-int(r.is_candidate), -r.alerts, -r.warns, r.agent_id),
    )
