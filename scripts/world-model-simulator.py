#!/usr/bin/env python3
"""world-model-simulator.py — SPEC-165: pre-action world-model simulation.

Simulates 3 outcomes (best/likely/worst) for a proposed action before
execution, using heuristics based on action type and context.

Usage:
  python3 scripts/world-model-simulator.py --action "edit AGENTS.md" --context "add new agent"
  python3 scripts/world-model-simulator.py --action "delete config.json" --context "cleanup"
  python3 scripts/world-model-simulator.py --action "deploy to prod" --context "hotfix"
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any

# ── Action classification ──────────────────────────────────────────────────────

ACTION_TYPES = {
    "edit": {
        "keywords": ["edit", "update", "modify", "patch", "change", "refactor", "rewrite",
                     "replace", "fix", "add line", "remove line"],
        "base_reversibility": True,
        "risk_base": 0.3,
    },
    "create": {
        "keywords": ["create", "write", "add file", "new file", "generate", "scaffold",
                     "init", "bootstrap", "mkdir"],
        "base_reversibility": True,
        "risk_base": 0.2,
    },
    "delete": {
        "keywords": ["delete", "remove", "drop", "rm ", "destroy", "unlink", "truncate"],
        "base_reversibility": False,
        "risk_base": 0.7,
    },
    "deploy": {
        "keywords": ["deploy", "release", "push to", "publish", "ship", "rollout",
                     "apply", "terraform apply", "kubectl apply", "merge to main"],
        "base_reversibility": False,
        "risk_base": 0.8,
    },
    "read": {
        "keywords": ["read", "list", "show", "get", "fetch", "query", "search", "inspect"],
        "base_reversibility": True,
        "risk_base": 0.0,
    },
}

RISK_AMPLIFIERS = {
    "prod": 0.3,
    "production": 0.3,
    "main branch": 0.2,
    "database": 0.25,
    "secret": 0.3,
    "credential": 0.3,
    "migration": 0.2,
    "schema": 0.15,
    "large file": 0.1,
    "critical": 0.2,
    "irreversible": 0.35,
    "force": 0.2,
    "--force": 0.2,
    "truncate": 0.25,
}

RULE_CHECKS = {
    "Rule #11": (
        re.compile(r"\b(\d{3,})\s*(lines?|loc)\b", re.I),
        "File may exceed 500-line limit (Rule #11).",
    ),
    "Rule #20": (
        re.compile(r"\b(pat|token|secret|password|credential|api.key)\b", re.I),
        "Action may involve PII/credentials (Rule #20).",
    ),
    "Rule #22": (
        re.compile(r"\b(large|heavy|big)\b.*\b(file|payload)\b", re.I),
        "Action may violate file-size constraints (Rule #22).",
    ),
}


# ── Core simulation ───────────────────────────────────────────────────────────

def _classify_action(action: str) -> tuple[str, dict]:
    """Classify action string into an action type."""
    action_lower = action.lower()
    for atype, info in ACTION_TYPES.items():
        for kw in info["keywords"]:
            if kw in action_lower:
                return atype, info
    # Default: edit
    return "edit", ACTION_TYPES["edit"]


def _compute_risk(action: str, context: str, action_type: str, base_risk: float) -> float:
    """Compute final risk score [0, 1]."""
    combined = (action + " " + context).lower()
    risk = base_risk
    for signal, delta in RISK_AMPLIFIERS.items():
        if signal in combined:
            risk += delta
    return min(1.0, risk)


def _rule_violations(action: str, context: str) -> list[str]:
    """Detect likely rule violations from text patterns."""
    combined = action + " " + context
    violations = []
    for rule_id, (pattern, msg) in RULE_CHECKS.items():
        if pattern.search(combined):
            violations.append(f"{rule_id}: {msg}")
    return violations


def _scenario_texts(action_type: str, risk: float, violations: list[str],
                    reversible: bool) -> list[dict]:
    """Generate the 3 scenarios based on action type and risk level."""
    action_map = {
        "edit": ("file updated successfully", "partial update — some sections skipped",
                 "hook rejection / test failure"),
        "create": ("file created, tests pass", "file created, minor lint warnings",
                   "write blocked by hook or path collision"),
        "delete": ("deletion clean, no dependents", "deletion succeeds, stale refs remain",
                   "deletion breaks downstream imports/tests"),
        "deploy": ("deploy succeeds, all health checks pass",
                   "deploy succeeds with warnings, manual rollback may be needed",
                   "deploy fails, rollback required, service disruption"),
        "read": ("data retrieved correctly", "partial result due to permissions",
                 "query fails, timeout or access denied"),
    }
    best_desc, likely_desc, worst_desc = action_map.get(action_type, action_map["edit"])

    if violations:
        worst_desc += f" — violations: {'; '.join(violations)}"

    # Probability distribution based on risk
    best_prob = max(0.05, 0.7 - risk * 0.5)
    worst_prob = min(0.6, 0.05 + risk * 0.5)
    likely_prob = max(0.1, 1.0 - best_prob - worst_prob)

    return [
        {
            "scenario": "best",
            "probability": round(best_prob, 2),
            "description": best_desc,
            "reversible": True,
        },
        {
            "scenario": "likely",
            "probability": round(likely_prob, 2),
            "description": likely_desc,
            "reversible": reversible,
        },
        {
            "scenario": "worst",
            "probability": round(worst_prob, 2),
            "description": worst_desc,
            "reversible": reversible and risk < 0.5,
        },
    ]


def simulate(action: str, context: str = "") -> dict[str, Any]:
    """
    Simulate 3 outcomes for the given action+context.
    Returns JSON-serialisable dict.
    """
    t0 = time.time()

    action_type, type_info = _classify_action(action)
    base_risk = type_info["risk_base"]
    base_reversible = type_info["base_reversibility"]

    risk = _compute_risk(action, context, action_type, base_risk)
    violations = _rule_violations(action, context)
    outcomes = _scenario_texts(action_type, risk, violations, base_reversible)

    # Simulation confidence: higher for well-understood action types, lower for ambiguous
    type_confidence = {"read": 0.95, "create": 0.85, "edit": 0.80, "delete": 0.75, "deploy": 0.65}
    sim_confidence = type_confidence.get(action_type, 0.7)
    if violations:
        sim_confidence -= 0.05 * len(violations)
    sim_confidence = round(max(0.4, min(0.99, sim_confidence)), 2)

    latency_ms = round((time.time() - t0) * 1000, 1)

    # Telemetry
    try:
        tele_path = Path("output") / "world-model-predictions.jsonl"
        tele_path.parent.mkdir(parents=True, exist_ok=True)
        record = {
            "action_preview": action[:80],
            "action_type": action_type,
            "risk": round(risk, 3),
            "simulation_confidence": sim_confidence,
            "violations": violations,
            "latency_ms": latency_ms,
        }
        with tele_path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(record) + "\n")
    except Exception:
        pass

    return {
        "action": action,
        "action_type": action_type,
        "risk_score": round(risk, 3),
        "outcomes": outcomes,
        "rule_violations_predicted": violations,
        "simulation_confidence": sim_confidence,
        "latency_ms": latency_ms,
    }


# ── CLI ───────────────────────────────────────────────────────────────────────

def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="SPEC-165 world-model-simulator")
    p.add_argument("--action", required=True, help="Description of proposed action")
    p.add_argument("--context", default="", help="Additional context for simulation")
    p.add_argument("--quiet", action="store_true")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    result = simulate(args.action, args.context)
    print(json.dumps(result, indent=2))
    if not args.quiet:
        print(
            f"type={result['action_type']} risk={result['risk_score']} "
            f"confidence={result['simulation_confidence']} latency={result['latency_ms']}ms",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
