#!/usr/bin/env python3
"""salience.py — SE-268 S2: Salience scoring for event-driven federation.
Deterministic scoring: {novelty, impact, criticality, recurrence} → 0-1.
Only signals above threshold ascend to dome. Anti-stagnation detector.
Usage:
  python3 bridge/salience/salience.py score --text "..." --context beliefs.json
  python3 bridge/salience/salience.py detect-stagnation --loop-log loop.jsonl
"""
from __future__ import annotations

import argparse, hashlib, json, os, re, sys
from pathlib import Path
from typing import Optional

ROOT = Path(os.environ.get("SAVIA_ROOT", os.getcwd()))

def _tokenize(text: str) -> set[str]:
    tokens = re.findall(r"[a-z0-9]{3,}", text.lower())
    result = set(tokens)
    for i in range(len(tokens) - 1):
        result.add(f"{tokens[i]}_{tokens[i+1]}")
    return result

def _novelty(text: str, known_texts: list[str]) -> float:
    if not known_texts:
        return 1.0
    tokens_new = _tokenize(text)
    if not tokens_new:
        return 0.0
    max_overlap = 0.0
    for known in known_texts:
        tokens_known = _tokenize(known)
        if not tokens_known:
            continue
        overlap = len(tokens_new & tokens_known) / len(tokens_new | tokens_known)
        max_overlap = max(max_overlap, overlap)
    return 1.0 - max_overlap

def _impact(text: str, commitments: list[str], deps: list[str]) -> float:
    if not commitments and not deps:
        return 0.5
    text_lower = text.lower()
    hits = sum(1 for c in commitments if c.lower() in text_lower)
    hits += sum(1 for d in deps if d.lower() in text_lower)
    total = len(commitments) + len(deps) or 1
    return min(1.0, hits / total)

def _criticality(nivel: str, domain: str) -> float:
    n_map = {"N1": 0.2, "N2": 0.4, "N3": 0.7, "N4": 0.8, "N4a": 0.9, "N4b": 1.0}
    d_map = {"salud": 1.0, "legal": 1.0, "seguridad": 1.0, "finanzas": 0.9,
             "infraestructura": 0.7, "desarrollo": 0.5, "datos": 0.5,
             "documentacion": 0.3, "experimental": 0.2, "sandbox": 0.1}
    return (n_map.get(nivel, 0.5) + d_map.get(domain, 0.5)) / 2.0

def _recurrence(text: str, history: list[dict]) -> float:
    if not history:
        return 0.0
    tokens = _tokenize(text)
    if not tokens:
        return 0.0
    matches = 0
    for h in history:
        h_text = h.get("text", "") if isinstance(h, dict) else str(h)
        if tokens & _tokenize(h_text):
            matches += 1
    return min(1.0, matches / max(len(history), 1))

def salience_score(text: str, known_texts=None, commitments=None,
                   deps=None, nivel="N2", domain="desarrollo",
                   history=None, weights=None) -> dict:
    known_texts = known_texts or []
    commitments = commitments or []
    deps = deps or []
    history = history or []
    weights = weights or {"novelty": 0.3, "impact": 0.25, "criticality": 0.2, "recurrence": 0.25}

    n = _novelty(text, known_texts)
    i = _impact(text, commitments, deps)
    c = _criticality(nivel, domain)
    r = _recurrence(text, history)

    score = (n * weights["novelty"] + i * weights["impact"] +
             c * weights["criticality"] + r * weights["recurrence"])

    return {
        "score": round(score, 4),
        "content_hash": hashlib.sha256(text.encode()).hexdigest()[:16],
        "components": {"novelty": round(n,4), "impact": round(i,4),
                       "criticality": round(c,4), "recurrence": round(r,4)},
        "weights": weights,
        "threshold_passed": None,
        "deterministic": True,
    }

def detect_stagnation(loop_history: list[dict], max_consecutive=5,
                      similarity_threshold=0.7) -> dict:
    if len(loop_history) < max_consecutive:
        return {"stagnation_detected": False, "consecutive_similar": 0}
    recent = loop_history[-max_consecutive:]
    texts = [e.get("text","") if isinstance(e,dict) else str(e) for e in recent]
    outcomes = [e.get("outcome","") if isinstance(e,dict) else "" for e in recent]
    no_progress = len(set(outcomes)) == 1
    if len(texts) >= 2:
        sims = []
        for i in range(len(texts)-1):
            t1 = _tokenize(texts[i]); t2 = _tokenize(texts[i+1])
            if t1 and t2:
                sims.append(len(t1&t2)/len(t1|t2))
        avg_sim = sum(sims)/len(sims) if sims else 0
    else:
        avg_sim = 0
    stagnant = avg_sim >= similarity_threshold and no_progress
    return {"stagnation_detected": stagnant, "consecutive_similar": len(recent),
            "avg_similarity": round(avg_sim,4), "no_progress": no_progress,
            "recommendation": "elevate_salience" if stagnant else "continue"}

def elevate_salience(score_dict: dict, boost=0.3) -> dict:
    s = score_dict.copy()
    s["score"] = round(min(1.0, s["score"] + boost), 4)
    s["stagnation_boost"] = boost
    return s

def should_ascend(score_dict: dict, threshold=0.5, context="default") -> dict:
    score_dict["threshold_passed"] = score_dict["score"] >= threshold
    score_dict["threshold"] = threshold
    score_dict["context"] = context
    return score_dict

# ── CLI ────────────────────────────────────────────────────────────────
def main():
    p = argparse.ArgumentParser(description="SE-268 Salience Engine")
    sub = p.add_subparsers(dest="cmd")
    sp = sub.add_parser("score")
    sp.add_argument("--text", required=True)
    sp.add_argument("--known-texts", default=None)
    sp.add_argument("--commitments", default=None)
    sp.add_argument("--dependencies", default=None)
    sp.add_argument("--nivel", default="N2")
    sp.add_argument("--domain", default="desarrollo")
    sp.add_argument("--history", default=None)
    sp.add_argument("--threshold", type=float, default=0.5)
    sp.add_argument("--context", default="default")
    sp.add_argument("--weights", default=None)
    st = sub.add_parser("detect-stagnation")
    st.add_argument("--loop-log", required=True)
    st.add_argument("--max-consecutive", type=int, default=5)
    st.add_argument("--similarity", type=float, default=0.7)
    args = p.parse_args()

    if args.cmd == "score":
        kt = _load_json_list(args.known_texts)
        cm = _load_json_list(args.commitments)
        dp = _load_json_list(args.dependencies)
        hy = _load_jsonl_list(args.history)
        w = None
        if args.weights:
            with open(args.weights) as f:
                w = json.load(f)
        result = salience_score(args.text, kt, cm, dp, args.nivel, args.domain, hy, w)
        result = should_ascend(result, args.threshold, args.context)
        print(json.dumps(result, indent=2, ensure_ascii=False))
        sys.exit(0 if result["threshold_passed"] else 1)
    elif args.cmd == "detect-stagnation":
        hy = _load_jsonl_list(args.loop_log)
        result = detect_stagnation(hy, args.max_consecutive, args.similarity)
        print(json.dumps(result, indent=2))
        sys.exit(1 if result["stagnation_detected"] else 0)
    else:
        p.print_help()

def _load_json_list(path):
    if not path or not os.path.exists(path):
        return []
    with open(path) as f:
        data = json.load(f)
    if isinstance(data, list):
        return [json.dumps(d,ensure_ascii=False) if isinstance(d,dict) else str(d) for d in data]
    return [json.dumps(data,ensure_ascii=False)]

def _load_jsonl_list(path):
    if not path or not os.path.exists(path):
        return []
    entries = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    entries.append(json.loads(line))
                except json.JSONDecodeError:
                    entries.append({"text": line})
    return entries

if __name__ == "__main__":
    main()
