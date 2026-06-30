#!/usr/bin/env python3
"""
scripts/sdd-reaction-engine.py — SPEC-050: Reaction Engine for SDD Pipeline

Listens to SDD pipeline events and determines the next recommended action
according to declarative rules in .opencode/reaction-rules.yaml.

CLI:
    python3 scripts/sdd-reaction-engine.py --event spec-approved --context "SPEC-123"
    python3 scripts/sdd-reaction-engine.py --event tests-failed --context "3 failures in auth"
    python3 scripts/sdd-reaction-engine.py --list-events

Events: spec-approved, pr-created, tests-failed, review-done,
        ci-failed, changes-requested, approved-and-green, agent-stuck

Output JSON:
    {
        "event": str,
        "action": str,
        "auto": bool,
        "retries_allowed": int,
        "escalate_after": int,
        "message": str
    }
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any

# ── Attempt YAML import (optional) ────────────────────────────────────────────
try:
    import yaml  # type: ignore
    _HAS_YAML = True
except ImportError:
    _HAS_YAML = False


# ── Known SDD pipeline events ─────────────────────────────────────────────────
KNOWN_EVENTS: frozenset[str] = frozenset({
    "spec-approved",
    "pr-created",
    "tests-failed",
    "review-done",
    "ci-failed",
    "changes-requested",
    "approved-and-green",
    "agent-stuck",
    "merge-conflicts",
})

# ── Built-in default rules (used when reaction-rules.yaml absent/unparseable) ─
DEFAULT_RULES: dict[str, dict[str, Any]] = {
    "spec-approved": {
        "action": "notify",
        "auto": True,
        "retries": 0,
        "escalate_after": 0,
        "message": "Spec approved. Assign to developer agent for implementation.",
    },
    "pr-created": {
        "action": "trigger-ci",
        "auto": True,
        "retries": 0,
        "escalate_after": 0,
        "message": "PR created. CI pipeline triggered automatically.",
    },
    "tests-failed": {
        "action": "send-to-agent",
        "auto": True,
        "retries": 2,
        "escalate_after": 3,
        "message": "Tests failed. Re-injecting failure context to developer agent.",
    },
    "review-done": {
        "action": "notify",
        "auto": True,
        "retries": 0,
        "escalate_after": 0,
        "message": "Review completed. Check for requested changes.",
    },
    "ci-failed": {
        "action": "send-to-agent",
        "auto": True,
        "retries": 2,
        "escalate_after": 3,
        "message": "CI failed. Forwarding CI logs to developer agent for fix.",
    },
    "changes-requested": {
        "action": "send-to-agent",
        "auto": True,
        "retries": 1,
        "escalate_after": 2,
        "message": "Changes requested. Forwarding review comments to agent.",
    },
    "approved-and-green": {
        "action": "notify",
        "auto": False,
        "retries": 0,
        "escalate_after": 0,
        "message": "PR approved and CI green. Human decision required for merge (autonomous-safety.md).",
    },
    "agent-stuck": {
        "action": "notify",
        "auto": True,
        "retries": 0,
        "escalate_after": 1,
        "message": "Agent has been idle > threshold. Escalating to human.",
    },
    "merge-conflicts": {
        "action": "notify",
        "auto": True,
        "retries": 0,
        "escalate_after": 1,
        "message": "Merge conflicts detected. Human resolution required.",
    },
}


@dataclass
class ReactionResult:
    event: str
    action: str
    auto: bool
    retries_allowed: int
    escalate_after: int
    message: str
    source: str = "default"  # "default" | "rules-file"

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


# ── Rules loader ───────────────────────────────────────────────────────────────

def _load_yaml_rules(rules_path: Path) -> dict[str, dict[str, Any]] | None:
    """Load reaction rules from YAML file. Returns None on failure."""
    if not rules_path.exists():
        return None
    if not _HAS_YAML:
        # Minimal YAML parser for simple key: value structures
        return _parse_minimal_yaml(rules_path)
    try:
        with open(rules_path) as f:
            data = yaml.safe_load(f)
        if isinstance(data, dict) and "reactions" in data:
            return data["reactions"]
        return data
    except Exception:
        return None


def _parse_minimal_yaml(path: Path) -> dict[str, dict[str, Any]] | None:
    """Very minimal YAML parser for the reaction-rules.yaml structure."""
    try:
        rules: dict[str, dict[str, Any]] = {}
        current_event: str | None = None
        current_rule: dict[str, Any] = {}
        in_reactions = False

        with open(path) as f:
            for raw_line in f:
                line = raw_line.rstrip()
                stripped = line.lstrip()

                if stripped.startswith("reactions:"):
                    in_reactions = True
                    continue

                if not in_reactions:
                    continue

                # Top-level event key (2-space indent + key:)
                if line.startswith("  ") and not line.startswith("    ") and stripped.endswith(":"):
                    if current_event and current_rule:
                        rules[current_event] = current_rule
                    current_event = stripped.rstrip(":")
                    current_rule = {}
                    continue

                # Nested key-value (4-space indent)
                if line.startswith("    ") and ":" in stripped and current_event:
                    key, _, val = stripped.partition(":")
                    val = val.strip().strip('"').strip("'")
                    # Type coercion
                    if val.lower() in ("true", "yes"):
                        parsed_val: Any = True
                    elif val.lower() in ("false", "no"):
                        parsed_val = False
                    else:
                        try:
                            parsed_val = int(val)
                        except ValueError:
                            parsed_val = val
                    current_rule[key.strip()] = parsed_val

        # Last event
        if current_event and current_rule:
            rules[current_event] = current_rule

        return rules if rules else None
    except Exception:
        return None


# ── Core reaction logic ────────────────────────────────────────────────────────

def resolve_reaction(
    event: str,
    context: str = "",
    rules_path: Path | None = None,
) -> ReactionResult:
    """Determine the reaction for a given SDD pipeline event."""

    # Load rules file if provided/exists
    file_rules: dict[str, dict[str, Any]] | None = None
    source = "default"

    if rules_path is None:
        # Default location
        _repo_root = Path(os.environ.get("PROJECT_ROOT", Path(__file__).parent.parent))
        rules_path = _repo_root / ".opencode" / "reaction-rules.yaml"

    file_rules = _load_yaml_rules(rules_path)
    if file_rules:
        source = "rules-file"

    # Merge: file rules override defaults
    effective_rules = {**DEFAULT_RULES}
    if file_rules:
        for ev, rule in file_rules.items():
            if ev in effective_rules:
                effective_rules[ev] = {**effective_rules[ev], **rule}
            else:
                effective_rules[ev] = rule

    if event not in effective_rules:
        return ReactionResult(
            event=event,
            action="unknown-event",
            auto=False,
            retries_allowed=0,
            escalate_after=0,
            message=f"Event '{event}' has no configured reaction. Manual intervention required.",
            source=source,
        )

    rule = effective_rules[event]

    # Build contextual message
    base_msg = rule.get("message", f"Reaction for {event} triggered.")
    if context:
        base_msg = f"{base_msg} Context: {context}"

    return ReactionResult(
        event=event,
        action=str(rule.get("action", "notify")),
        auto=bool(rule.get("auto", False)),
        retries_allowed=int(rule.get("retries", 0)),
        escalate_after=int(rule.get("escalate_after", 0)),
        message=base_msg,
        source=source,
    )


# ── CLI ───────────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="sdd-reaction-engine.py",
        description="SPEC-050: SDD Pipeline Reaction Engine — determines next action for pipeline events",
    )
    p.add_argument(
        "--event",
        metavar="EVENT",
        help=f"Pipeline event. Known: {', '.join(sorted(KNOWN_EVENTS))}",
    )
    p.add_argument(
        "--context",
        default="",
        metavar="TEXT",
        help="Additional context about the event (optional)",
    )
    p.add_argument(
        "--rules",
        default=None,
        metavar="PATH",
        help="Path to reaction-rules.yaml (default: .opencode/reaction-rules.yaml)",
    )
    p.add_argument(
        "--list-events",
        action="store_true",
        help="List all known events and exit",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.list_events:
        events = sorted(KNOWN_EVENTS)
        print(json.dumps({"known_events": events}, indent=2))
        return 0

    if not args.event:
        parser.print_help()
        return 1

    rules_path = Path(args.rules) if args.rules else None
    result = resolve_reaction(args.event, args.context, rules_path)
    print(json.dumps(result.to_dict(), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
