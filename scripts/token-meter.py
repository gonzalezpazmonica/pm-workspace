#!/usr/bin/env python3
"""token-meter.py — SE-326 S3: medición determinista de la superficie de una sesión.

Inspirado en deepseek-harness packages/llm/token-meter (SE-326).

Emite un snapshot inmutable de presión de contexto:
  {log_revision, baseline, surface_delta_tokens, total_tokens, surface_tokens,
   nodes: [{seq, tokens}]}

- surface_tokens = suma de tokens de los nodos (heurística chars/4 por rol,
  tool result x3).
- baseline provider: si existe `usage` del último call (telemetría savia.event/1.0
  SE-313), se reutiliza como ancla; si no, estimación heurística completa.
- log_revision = nº de eventos consumidos (derivado del trace log si existe).
- Medición O(surface) — no muta nada.

Uso:
  token-meter.py --session <id> [--surface '<json>'|--surface-file <path>] [--usage <n>]
  token-meter.py --emit <id> --emit-script <otel-emit.sh> [--surface ...]
"""

import argparse
import json
import os
import sys

ROLE_WEIGHT = {
    "user": 1.0,
    "assistant": 1.2,
    "tool_result": 3.0,
    "tool_call": 1.0,
    "system": 1.0,
}


def estimate_tokens(text: str, role: str = "user") -> int:
    """Heurística: framing + chars/4, ajustada por tipo de contenido."""
    framing = 8 if role != "tool_result" else 16
    raw = len(text or "")
    return framing + int(raw / 4 * ROLE_WEIGHT.get(role, 1.0))


def load_surface(raw: str) -> list:
    if not raw or raw.strip() == "":
        return []
    try:
        parsed = json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return []
    if isinstance(parsed, list):
        return parsed
    if isinstance(parsed, dict):
        return parsed.get("nodes", [])
    return []


def derive_log_revision(session: str, project_dir: str) -> int:
    """Nº de eventos duraderos consumidos — derivado del trace log si existe."""
    trace = os.path.join(project_dir, "output", "agent-traces.jsonl")
    if not os.path.exists(trace):
        return 0
    try:
        with open(trace, encoding="utf-8") as fh:
            return sum(1 for line in fh if line.strip())
    except OSError:
        return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--session", required=True)
    parser.add_argument("--surface", default="", help="surface as JSON list of {role, text} or {seq, tokens}")
    parser.add_argument("--surface-file", default="", help="path to surface JSON")
    parser.add_argument("--usage", type=int, default=0, help="provider usage total del último call")
    parser.add_argument("--project-dir", default="")
    parser.add_argument("--emit", default="", help="session id para telemetría")
    parser.add_argument("--emit-script", default="", help="path a otel-emit.sh")
    parser.add_argument("--out", default="", help="path destino del snapshot (default stdout)")
    args = parser.parse_args()

    project_dir = args.project_dir or os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())

    surface = load_surface(args.surface)
    if args.surface_file and os.path.exists(args.surface_file):
        with open(args.surface_file, encoding="utf-8") as fh:
            surface = load_surface(fh.read())

    nodes = []
    for i, node in enumerate(surface):
        if isinstance(node, dict) and "tokens" in node:
            tokens = int(node["tokens"])
            seq = node.get("seq", i)
        else:
            role = node.get("role", "user") if isinstance(node, dict) else "user"
            text = node.get("text", "") if isinstance(node, dict) else str(node)
            tokens = estimate_tokens(text, role)
            seq = i
        nodes.append({"seq": seq, "tokens": tokens})

    surface_tokens = sum(n["tokens"] for n in nodes)

    log_revision = derive_log_revision(args.session, project_dir)
    baseline_kind = "usage" if args.usage > 0 else "estimated"
    total_tokens = max(args.usage, surface_tokens) if args.usage > 0 else surface_tokens
    surface_delta = surface_tokens - args.usage if args.usage > 0 else surface_tokens

    snapshot = {
        "session": args.session,
        "log_revision": log_revision,
        "baseline": {"kind": baseline_kind, "anchor_tokens": args.usage},
        "surface_delta_tokens": surface_delta,
        "total_tokens": total_tokens,
        "surface_tokens": surface_tokens,
        "nodes": nodes,
    }

    if args.out:
        out_dir = os.path.dirname(args.out)
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as fh:
            json.dump(snapshot, fh, ensure_ascii=False, indent=2)
    else:
        print(json.dumps(snapshot, ensure_ascii=False))

    if args.emit and args.emit_script and os.path.exists(args.emit_script):
        try:
            import subprocess

            subprocess.run(
                [
                    "bash",
                    args.emit_script,
                    "savia.token-meter",
                    f"session={args.session}",
                    f"total_tokens={total_tokens}",
                    f"surface_tokens={surface_tokens}",
                    f"baseline={baseline_kind}",
                    f"nodes={len(nodes)}",
                ],
                capture_output=True,
                check=False,
            )
        except Exception:
            pass

    return 0


if __name__ == "__main__":
    sys.exit(main())
