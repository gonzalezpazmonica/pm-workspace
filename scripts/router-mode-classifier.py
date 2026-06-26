#!/usr/bin/env python3
"""router-mode-classifier.py — SPEC-163 Slice 1.

Heuristic classifier for System 1 / System 2 dispatch.

Input  (stdin or --input): JSON {intent, command, has_code_change, estimated_tokens}
Output (stdout):            JSON {mode, confidence, reason, complexity_tier}

Exit codes:
  0  — success
  1  — invalid JSON input (fail-soft: returns mode2 conservative default)
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

# ─── mode1 query patterns ────────────────────────────────────────────────────
MODE1_QUERY_PATTERNS = re.compile(
    r"\b(estado|cuántos|cuantos|listar|lista|ver|show|status|sprint|daily|"
    r"focus|board|flujo|progreso|burndown|velocidad|velocity|what|who|"
    r"where|when|cuál|cual|qué|que\s+hay|dame|muéstrame|muestrame|"
    r"cómo\s+va|como\s+va|resumen|summary|report|informe|check)\b",
    re.IGNORECASE,
)

# ─── mode2 action patterns ───────────────────────────────────────────────────
MODE2_ACTION_PATTERNS = re.compile(
    r"\b(crear|create|modificar|modify|implementar|implement|commit|merge|"
    r"push|deploy|escribir|write|editar|edit|borrar|delete|eliminar|remove|"
    r"instalar|install|configurar|configure|añadir|add|update|actualizar|"
    r"refactor|fix|arreglar|resolver|solve|build|compile|test|spec|pr|pull\s*request|"
    r"migrate|migrar)\b",
    re.IGNORECASE,
)

# ─── mode1 commands (declared complexity_tier: mode1 in frontmatter) ─────────
MODE1_COMMANDS = frozenset(
    {
        "sprint-status",
        "my-sprint",
        "my-focus",
        "board-flow",
        "daily-routine",
        "savia-live",
        "help",
        "index-compact",
        "compact",
    }
)

# ─── mode2 commands (declared complexity_tier: mode2 in frontmatter) ─────────
MODE2_COMMANDS = frozenset(
    {
        "savia-shield",
        "spec-write",
        "sdd-spec",
        "commit",
        "pr-create",
        "pr-merge",
        "infra-create",
        "agent-task",
        "overnight-sprint",
        "code-review",
    }
)

TOKEN_THRESHOLD = 5000


def _lookup_command_tier(command: str) -> str | None:
    """Check frontmatter-declared complexity_tier if command file exists."""
    if not command:
        return None
    commands_dir = Path(__file__).resolve().parents[1] / ".opencode" / "commands"
    candidate = commands_dir / f"{command}.md"
    if not candidate.is_file():
        return None
    try:
        content = candidate.read_text(encoding="utf-8")
        # Fast frontmatter scan — no yaml dep required
        in_front = False
        for line in content.splitlines():
            if line.strip() == "---":
                in_front = not in_front
                continue
            if in_front and line.startswith("complexity_tier:"):
                val = line.split(":", 1)[1].strip().strip('"').strip("'")
                if val in ("mode1", "mode2", "auto"):
                    return val
    except OSError:
        pass
    return None


def classify(payload: dict[str, Any]) -> dict[str, Any]:
    """Apply heuristics and return classification dict."""
    intent: str = str(payload.get("intent", ""))
    command: str = str(payload.get("command", ""))
    has_code_change: bool = bool(payload.get("has_code_change", False))
    estimated_tokens: int = int(payload.get("estimated_tokens", 0))

    # ── Rule 1: code change → always mode2 ───────────────────────────────────
    if has_code_change:
        return {
            "mode": "mode2",
            "confidence": 1.0,
            "reason": "has_code_change=true forces mode2",
            "complexity_tier": "mode2",
        }

    # ── Rule 2: token threshold ───────────────────────────────────────────────
    if estimated_tokens > TOKEN_THRESHOLD:
        return {
            "mode": "mode2",
            "confidence": 0.95,
            "reason": f"estimated_tokens={estimated_tokens} > {TOKEN_THRESHOLD}",
            "complexity_tier": "mode2",
        }

    # ── Rule 3: declared frontmatter tier ────────────────────────────────────
    declared = _lookup_command_tier(command)
    if declared == "mode1":
        return {
            "mode": "mode1",
            "confidence": 0.95,
            "reason": f"command '{command}' declares complexity_tier=mode1",
            "complexity_tier": "mode1",
        }
    if declared == "mode2":
        return {
            "mode": "mode2",
            "confidence": 0.95,
            "reason": f"command '{command}' declares complexity_tier=mode2",
            "complexity_tier": "mode2",
        }

    # ── Rule 4: known command sets ────────────────────────────────────────────
    if command in MODE1_COMMANDS:
        return {
            "mode": "mode1",
            "confidence": 0.90,
            "reason": f"command '{command}' in mode1 allowlist",
            "complexity_tier": "mode1",
        }
    if command in MODE2_COMMANDS:
        return {
            "mode": "mode2",
            "confidence": 0.90,
            "reason": f"command '{command}' in mode2 allowlist",
            "complexity_tier": "mode2",
        }

    # ── Rule 5: intent pattern matching ──────────────────────────────────────
    has_query = bool(MODE1_QUERY_PATTERNS.search(intent))
    has_action = bool(MODE2_ACTION_PATTERNS.search(intent))

    if has_action and has_query:
        # Mixed intent — conservative default
        return {
            "mode": "mode2",
            "confidence": 0.65,
            "reason": "intent has both query and action signals — conservative mode2",
            "complexity_tier": "auto",
        }

    if has_action and not has_query:
        return {
            "mode": "mode2",
            "confidence": 0.85,
            "reason": "intent contains action patterns",
            "complexity_tier": "mode2",
        }

    if has_query and not has_action:
        return {
            "mode": "mode1",
            "confidence": 0.80,
            "reason": "intent contains query patterns without action signals",
            "complexity_tier": "mode1",
        }

    # ── Default: conservative mode2 ──────────────────────────────────────────
    return {
        "mode": "mode2",
        "confidence": 0.60,
        "reason": "no matching pattern — conservative default mode2",
        "complexity_tier": "auto",
    }


def main() -> int:
    raw = sys.stdin.read().strip()
    if not raw:
        raw = "{}"
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        result = {
            "mode": "mode2",
            "confidence": 1.0,
            "reason": f"invalid JSON input ({exc}) — fail-soft conservative default",
            "complexity_tier": "auto",
        }
        print(json.dumps(result))
        return 1

    result = classify(payload)
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
