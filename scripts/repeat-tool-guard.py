#!/usr/bin/env python3
"""repeat-tool-guard.py — SE-326 S1: detecta llamadas de tool repetidas idénticas.

Inspirado en deepseek-harness packages/guard/repeat-tool-reminder (SE-326).

Chain key = (tool_name, canonicalized args). Una llamada idéntica a la anterior
incrementa el contador consecutivo de esa (sesion, turno); una llamada distinta
lo resetea a 1. Al cruzar un threshold se imprime un recordatorio a stderr
(jamas bloquea). Las llamadas excluidas (bookkeeping) no incrementan ni resetean
la cadena.

NUNCA bloquea: exit 0 siempre. Estado persistido por (sesion, turno) en
output/loop-guard/{session}.json — cada PostToolUse es un proceso nuevo, por lo
que la persistencia es obligatoria para que el guard funcione.

Uso:
  repeat-tool-guard.py --session <id> [--turn <turn_id>] --tool <name> \\
      --args '<json args>' [--exclude 'tool_a,tool_b'] [--thresholds 3,5,8] \\
      [--preview 500] [--state-dir output/loop-guard] [--no-persist]
"""

import argparse
import json
import os
import sys

DEFAULT_THRESHOLDS = [3, 5, 8]
DEFAULT_EXCLUDE = {"todo_write", "todowrite"}
DEFAULT_PREVIEW = 500


def canonicalize_args(raw: str) -> str:
    """Canonicaliza args: deep key-sort + json.dumps. Args en distinto orden = iguales."""
    if not raw or raw.strip() == "":
        return ""
    try:
        parsed = json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return raw.strip()
    return json.dumps(parsed, sort_keys=True, separators=(",", ":"))


def load_state(path: str) -> dict:
    if not os.path.exists(path):
        return {}
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return {}


def save_state(path: str, state: dict) -> None:
    tmp = f"{path}.tmp"
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(state, fh, ensure_ascii=False)
        os.replace(tmp, path)
    except OSError:
        pass


def build_reminder(tool: str, count: int, preview: int, canonical: str) -> str:
    snippet = canonical
    if len(snippet) > preview:
        snippet = snippet[:preview] + f"\u2026 (+{len(canonical) - preview} more chars)"
    return (
        "\n[loop-guard] Repeated tool call detected:\n"
        f"- tool: {tool}\n"
        f"- consecutive_calls: {count}\n"
        f"- arguments: {snippet}\n"
        "Carefully analyze the previous result before calling again: "
        "if the task is not complete, try a different approach or different "
        "arguments instead of repeating the call.\n"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--session", required=True, help="session id (CLAUDE_SESSION_ID)")
    parser.add_argument("--turn", default="", help="turn id (CLAUDE_TURN_ID) — resets chain on change")
    parser.add_argument("--tool", required=True, help="tool name")
    parser.add_argument("--args", default="", help="tool args as JSON string")
    parser.add_argument("--exclude", default="", help="comma-separated tool names excluded from chain")
    parser.add_argument("--thresholds", default="", help="comma-separated ascending thresholds")
    parser.add_argument("--preview", type=int, default=DEFAULT_PREVIEW, help="args preview cap")
    parser.add_argument("--state-dir", default="output/loop-guard")
    parser.add_argument("--no-persist", action="store_true",
                        help="NO persistir estado (cada PostToolUse es un proceso nuevo; el guard exige persistencia)")
    parser.add_argument("--emit-telemetry", default="", help="path to otel-emit.sh (optional)")
    args = parser.parse_args()

    thresholds = sorted(set(DEFAULT_THRESHOLDS))
    if args.thresholds.strip():
        try:
            parsed = [int(t) for t in args.thresholds.split(",") if t.strip()]
            if parsed and all(t >= 2 for t in parsed) and len(parsed) == len(set(parsed)):
                thresholds = sorted(parsed)
        except ValueError:
            pass

    exclude = set(DEFAULT_EXCLUDE)
    if args.exclude.strip():
        exclude |= {t.strip() for t in args.exclude.split(",") if t.strip()}

    # bookkeeping tools are transparent to the chain
    if args.tool in exclude:
        return 0

    key = f"{args.session}:::{args.turn or 'default'}"

    # estado por (sesion, turno); persistido SIEMPRE (cada PostToolUse es proceso nuevo)
    state_path = os.path.join(args.state_dir, f"{args.session}.json")
    state = load_state(state_path) if not args.no_persist else {}

    chain = state.get(key)
    if chain is None or chain.get("turn") != args.turn:
        chain = {"turn": args.turn, "tool": None, "canonical": None, "count": 0}

    canonical = canonicalize_args(args.args)

    if chain["tool"] == args.tool and chain["canonical"] == canonical:
        chain["count"] += 1
    else:
        chain["tool"] = args.tool
        chain["canonical"] = canonical
        chain["count"] = 1

    state[key] = chain

    hit_threshold = chain["count"] in thresholds
    if not args.no_persist:
        save_state(state_path, state)

    if hit_threshold:
        first = chain["count"] == thresholds[0]
        if first:
            print(
                "\n[loop-guard] You are repeating the exact same tool call with identical "
                "arguments. Carefully analyze the previous result before calling again: "
                "if the task is not complete, try a different approach or different "
                "arguments instead of repeating the call.\n",
                file=sys.stderr,
            )
        else:
            print(build_reminder(args.tool, chain["count"], args.preview, canonical), file=sys.stderr)

        if args.emit_telemetry and os.path.exists(args.emit_telemetry):
            try:
                import subprocess

                subprocess.run(
                    [
                        "bash",
                        args.emit_telemetry,
                        "savia.loop-guard",
                        f"tool={args.tool}",
                        f"run_length={chain['count']}",
                        f"threshold={chain['count']}",
                    ],
                    capture_output=True,
                    check=False,
                )
            except Exception:
                pass

    return 0


if __name__ == "__main__":
    sys.exit(main())
