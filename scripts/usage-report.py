#!/usr/bin/env python3
"""usage-report.py — SE-380 §17: telemetría de uso LOCAL (metadata-only).

Agrega fuentes locales existentes sin contenido de conversación:
  - data/skill-invocations.jsonl (SPEC-SE-030: {ts, skill, command, session_id})
  - output/router-decisions.jsonl (si existe)
Salida: output/usage-report.md (+json) determinista. Sin red, sin N3+.
"""
from __future__ import annotations

import json
import os
import sys
from collections import Counter


def read_jsonl(path: str) -> list:
    if not os.path.exists(path):
        return []
    out = []
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.strip()
        if line:
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return out


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    inv = read_jsonl(os.path.join(root, "data", "skill-invocations.jsonl"))
    router = read_jsonl(os.path.join(root, "output", "router-decisions.jsonl"))

    per_skill = Counter()
    last_used = {}
    for r in inv:
        sk = r.get("skill") or "unknown"
        per_skill[sk] += 1
        ts = r.get("ts", "")
        if sk not in last_used or str(ts) > str(last_used[sk]):
            last_used[sk] = ts

    reg_path = os.path.join(root, ".scm", "registry.json")
    reg = json.load(open(reg_path, encoding="utf-8")) if os.path.exists(reg_path) else {"capabilities": []}
    skills = sorted(c["id"] for c in reg["capabilities"] if c["kind"] == "skill")
    skill_names = {s.split(":", 1)[1] for s in skills}

    never_used = sorted(skill_names - set(per_skill))

    lines = ["# Usage Report local (SE-380)", "",
             f"Invocaciones registradas: {len(inv)} · skills: {len(skill_names)} · "
             f"con uso: {len(per_skill) - (1 if 'unknown' in per_skill else 0)} · "
             f"sin uso registrado: {len(never_used)} · decisiones router: {len(router)}", "",
             "| skill | invocaciones | last_used |", "|---|---|---|"]
    for sk, n in per_skill.most_common():
        lines.append(f"| {sk} | {n} | {last_used.get(sk, '')} |")
    lines += ["", "## Skills sin uso registrado (candidatas a revisión lifecycle, propuesta)", ""]
    lines += [f"- {s}" for s in never_used] or ["- (ninguna)"]

    outdir = os.path.join(root, "output")
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, "usage-report.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"usage-report: {len(inv)} invocaciones, {len(never_used)} skills sin uso → output/usage-report.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
