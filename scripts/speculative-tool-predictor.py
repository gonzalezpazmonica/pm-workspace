#!/usr/bin/env python3
"""
speculative-tool-predictor.py — Heuristic tool call predictor (SE-220 S1).

Input  (stdin or --input):
  {"intent": "texto del usuario", "available_tools": ["Bash", "Read", "Grep", "Edit", "Write"]}

Output (stdout, JSON):
  {
    "predicted_tools": ["Read", "Grep"],
    "confidence": 0.72,
    "rationale": "...",
    "whitelist_only": true
  }

whitelist_only: true if ALL predicted_tools are in the READ_ONLY_WHITELIST.
Read-only whitelist: ["Read", "Grep", "Glob", "Bash"] — idempotent, no side effects.

--validate mode:
  Input: {"predicted_tools": [...], "actual_tool": "Read"}
  Exit 0 if actual_tool is in predicted_tools, exit 1 otherwise.

Ref: SE-220 — Speculative Tool Execution (Slice 1)
"""
from __future__ import annotations

import json
import re
import sys
from typing import Any

# ─────────────────────────────────────────────────────────────────────────────
# Read-only whitelist — safe for speculative pre-execution (idempotent, no effects)
# ─────────────────────────────────────────────────────────────────────────────
READ_ONLY_WHITELIST: frozenset[str] = frozenset(["Read", "Grep", "Glob", "Bash"])

# ─────────────────────────────────────────────────────────────────────────────
# Pattern bank: (compiled_regex, tool, base_confidence, rationale_fragment)
# Ordered from most specific to least specific.  First N matching patterns
# are used; max 3 tools predicted (matching the Slice 1 top-3 design).
# ─────────────────────────────────────────────────────────────────────────────
# NOTE: Glob is treated as equivalent to Bash for listing patterns since the
# tool name "Glob" is less commonly used in intents; both are whitelisted.

_PATTERNS: list[tuple[re.Pattern, str, float, str]] = [
    # ── Write / create ───────────────────────────────────────────────────────
    (re.compile(r"\b(crea|crear|genera|generar|escribe|escribir|new file|create|write file|nuevo fichero|nuevo archivo)\b", re.I),
     "Write", 0.82, "creation/write intent"),

    # ── Edit / modify ────────────────────────────────────────────────────────
    (re.compile(r"\b(modifica|modificar|cambia|cambiar|actualiza|actualizar|edita|editar|refactoriza|refactor|fix|arregla|corrige|corregir|patch)\b", re.I),
     "Edit", 0.85, "modification intent"),

    # ── Bash / execute ───────────────────────────────────────────────────────
    (re.compile(r"\b(ejecuta|ejecutar|run|corre|correr|lanza|lanzar|compila|compilar|build|deploy|instala|instalar|npm|pip|pytest|bats|bash|shell|comando|command|script)\b", re.I),
     "Bash", 0.80, "execution/command intent"),

    # ── Grep / search content ────────────────────────────────────────────────
    (re.compile(r"\b(busca|buscar|encuentra|encontrar|search|grep|contiene|contains|pattern|patron|ocurrencias|occurrences|aparece|aparecen|donde usa|where is|find usages|callers|referencias|references)\b", re.I),
     "Grep", 0.78, "content search intent"),

    # ── Read / view ──────────────────────────────────────────────────────────
    (re.compile(r"\b(lee|leer|muestra|mostrar|ver|ve|show|display|imprime|print|abre|abrir|open|revisa|revisar|check|inspect|visualiza|visualizar|dame el contenido|contenido de)\b", re.I),
     "Read", 0.75, "read/view intent"),

    # ── Glob / list files ────────────────────────────────────────────────────
    (re.compile(r"\b(lista|listar|list files|qué ficheros|que ficheros|what files|glob|encuentra ficheros|find files|ls|dir)\b", re.I),
     "Bash", 0.70, "file listing intent"),

    # ── Sprint / ADO queries ─────────────────────────────────────────────────
    (re.compile(r"\b(sprint|backlog|wiql|azure devops|ado|velocity|burndown|capacity|pbi|work item|iteration|board)\b", re.I),
     "Bash", 0.73, "ADO/sprint management intent → WIQL query via Bash"),

    # ── Git operations ───────────────────────────────────────────────────────
    (re.compile(r"\b(git|commit|branch|diff|log|status|merge|push|pull|pr|pull request)\b", re.I),
     "Bash", 0.76, "git operation intent"),

    # ── Test / verify ────────────────────────────────────────────────────────
    (re.compile(r"\b(test|tests|prueba|pruebas|valida|validar|verifica|verificar|coverage|cobertura)\b", re.I),
     "Bash", 0.72, "test execution intent"),

    # ── Architecture / structure ─────────────────────────────────────────────
    (re.compile(r"\b(arquitectura|architecture|estructura|structure|diagrama|diagram|diseño|design|doc|documento)\b", re.I),
     "Read", 0.68, "documentation/architecture query intent"),

    # ── Security / audit ────────────────────────────────────────────────────
    (re.compile(r"\b(seguridad|security|audit|auditoria|vulnerabilidad|vulnerability|owasp|cve|pentest)\b", re.I),
     "Bash", 0.74, "security audit intent"),

    # ── Memory / recall ─────────────────────────────────────────────────────
    (re.compile(r"\b(memoria|memory|recuerda|recuerdas|recall|guarda|guardar|save)\b", re.I),
     "Bash", 0.65, "memory operation intent"),
]

_DEFAULT_TOOL = "Read"
_DEFAULT_CONFIDENCE = 0.50
_MAX_PREDICTIONS = 3


def predict(intent: str, available_tools: list[str]) -> dict[str, Any]:
    """Return predicted_tools, confidence, rationale for a given intent."""
    available_set = set(available_tools)

    matched: list[tuple[str, float, str]] = []
    seen_tools: set[str] = set()

    for pattern, tool, conf, rationale in _PATTERNS:
        if tool not in available_set:
            continue
        if tool in seen_tools:
            continue
        if pattern.search(intent):
            matched.append((tool, conf, rationale))
            seen_tools.add(tool)
        if len(matched) >= _MAX_PREDICTIONS:
            break

    if not matched:
        # Fallback: default to Read if available, else first available
        default = _DEFAULT_TOOL if _DEFAULT_TOOL in available_set else (available_tools[0] if available_tools else "Read")
        return {
            "predicted_tools": [default],
            "confidence": _DEFAULT_CONFIDENCE,
            "rationale": "no pattern matched — defaulting to Read",
            "whitelist_only": default in READ_ONLY_WHITELIST,
        }

    # Aggregate: tools ranked by order of match; confidence = mean
    predicted_tools = [t for t, _, _ in matched]
    confidence = round(sum(c for _, c, _ in matched) / len(matched), 4)
    rationale_parts = [f"{t}: {r}" for t, _, r in matched]
    rationale = "; ".join(rationale_parts)

    return {
        "predicted_tools": predicted_tools,
        "confidence": confidence,
        "rationale": rationale,
        "whitelist_only": all(t in READ_ONLY_WHITELIST for t in predicted_tools),
    }


def validate(payload: dict[str, Any]) -> int:
    """--validate mode: exit 0 if actual_tool in predicted_tools, else exit 1."""
    predicted = payload.get("predicted_tools", [])
    actual = payload.get("actual_tool", "")
    if not actual:
        print(json.dumps({"error": "actual_tool field is required for --validate"}), file=sys.stderr)
        return 2
    match = actual in predicted
    print(json.dumps({"actual_tool": actual, "predicted_tools": predicted, "match": match}))
    return 0 if match else 1


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(
        description="Heuristic tool-call predictor (SE-220 S1)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--input", "-i", help="JSON string (alternative to stdin)")
    parser.add_argument("--validate", action="store_true",
                        help="Validate mode: check if actual_tool matches prediction. "
                             "Input: {predicted_tools:[...], actual_tool:'...'}. "
                             "Exit 0=match, 1=no match.")
    args = parser.parse_args()

    raw = args.input or sys.stdin.read().strip()
    if not raw:
        print(json.dumps({"error": "no input provided"}), file=sys.stderr)
        return 1

    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(json.dumps({"error": f"invalid JSON: {exc}"}), file=sys.stderr)
        return 1

    if args.validate:
        return validate(payload)

    intent = payload.get("intent", "")
    available_tools = payload.get("available_tools", ["Bash", "Read", "Grep", "Edit", "Write"])

    if not intent:
        print(json.dumps({"error": "intent field is required"}), file=sys.stderr)
        return 1

    result = predict(intent, available_tools)
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
