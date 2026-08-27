#!/usr/bin/env python3
"""l27-auditor-auditor.py — E13: auditor del auditor / anti-sello-de-goma.

Mide el CRITERIO de quien audita (meta-criterio):
  - sintético: dado un revisor con habilidad latente y sus decisiones+outcomes,
    ¿las métricas detectan revisor bueno vs sello-de-goma? (AUC, Brier, varianza)
  - real: piloto sobre el audit log de savia-gates (gates de Savia): tasa de
    bloqueo/aviso por tool, varianza temporal, concentración — ¿discriminan o
    firman por inercia?

CRIT-001: local; el audit log se resume por categorías (no se expone contenido).
"""

import argparse
import json
import os
import random
import sys
from datetime import datetime, timezone


def synthetic(n_reviews=200, seed=1, reviewer_type="good"):
    """Revisor sintético: good (criterio real) vs rubber (sello de goma)."""
    rng = random.Random(seed)
    rows = []
    latent = 0.65 if reviewer_type == "good" else 0.5
    for _ in range(n_reviews):
        prob_issue = rng.random()          # la revisión realmente tiene problema?
        noise = rng.gauss(0, 0.12) if reviewer_type == "good" else rng.gauss(0, 0.45)
        score = prob_issue + noise         # señal del revisor
        decision = 1 if score > 0.5 else 0  # 1 = marca problema / bloquea
        rows.append((prob_issue, decision))
    return rows


def metrics(rows):
    """AUC (Mann-Whitney U) de la decisión vs problema real + tasas."""
    issues = [r for r in rows if r[0] > 0.5]
    cleans = [r for r in rows if r[0] <= 0.5]
    pos = [d for (_, d) in issues]
    neg = [d for (_, d) in cleans]
    if not pos or not neg:
        return None
    u = sum(1 for p in pos for n in neg if p > n) + 0.5 * sum(1 for p in pos for n in neg if p == n)
    auc = u / (len(pos) * len(neg))
    block_rate = sum(d for (_, d) in rows) / len(rows)
    var = sum((d - block_rate) ** 2 for (_, d) in rows) / len(rows)
    return {"auc": round(auc, 3), "block_rate": round(block_rate, 3), "variance": round(var, 4)}


def audit_savia_gates(audit_path):
    """Piloto: resume el audit log de savia-gates por categoría (sin contenido)."""
    if not os.path.exists(audit_path):
        return None
    blocks = {}
    warns = {}
    days = {}
    for line in open(audit_path, encoding="utf-8"):
        try:
            d = json.loads(line)
        except Exception:
            continue
        ev = d.get("event", "")
        tool = d.get("tool", "?")
        if ev == "tool-blocked":
            blocks[tool] = blocks.get(tool, 0) + 1
        elif ev == "post-hook-warning":
            warns[tool] = warns.get(tool, 0) + 1
        if ev in ("tool-blocked", "post-hook-warning"):
            day = str(d.get("ts", ""))[:10]
            days[day] = days.get(day, 0) + 1
    total = sum(blocks.values()) + sum(warns.values())
    top = blocks or warns
    concentration = (max(top.values()) / total) if total else 0
    day_rates = [v for v in days.values()]
    day_var = (sum((v - sum(day_rates)/len(day_rates))**2 for v in day_rates) / len(day_rates)) if day_rates else 0
    return {
        "total_eventos_gate": total,
        "bloqueos": blocks,
        "avisos": warns,
        "concentracion_top_tool": round(concentration, 3),
        "varianza_diaria": round(day_var, 2),
        "dias_con_actividad": len(days),
    }


def main():
    ap = argparse.ArgumentParser(description="E13 auditor del auditor (L27)")
    ap.add_argument("--synthetic", action="store_true")
    ap.add_argument("--audit", default=os.path.join(os.environ.get("HOME", ""), ".savia", "audit", "savia-gates.jsonl"))
    args = ap.parse_args()

    out = {"ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
    if args.synthetic:
        for name in ("good", "rubber"):
            out[f"revisor_{name}"] = metrics(synthetic(reviewer_type=name))
    gate = audit_savia_gates(args.audit)
    if gate:
        out["gates_savia"] = gate
    print(json.dumps(out, ensure_ascii=False, indent=2))
    # Veredicto anti-sello-de-goma: en sintético, el bueno debe AUC > 0.6 y el rubber ~0.5
    if args.synthetic:
        good = out.get("revisor_good", {}).get("auc", 0)
        rubber = out.get("revisor_rubber", {}).get("auc", 0.5)
        verdict = "PASS: el auditor distingue revisor bueno (AUC %.2f) de sello-de-goma (AUC %.2f)" % (good, rubber)
        print(verdict, file=sys.stderr)
        if good <= 0.6 or rubber >= good - 0.1:
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
