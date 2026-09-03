#!/usr/bin/env python3
"""verdict-path.py — SE-367: Derivation Path en veredictos.

Todo veredicto lleva su path (spec 3.1): regla aplicada, premisas, refs y
eventos del trace observados. Grounding (L28 M2): un premise/evidence con
`ground: true` exige que el trace_event esté REALMENTE observado en el
trace — nunca una tool no ejecutada.

Persistencia: data/verdicts/<verdict_id>.json (aditivo: campo `path`).
CRIT-001: todo local, stdlib puro, sin red.

Uso:
  verdict-path.py attach VERDICT.json --rule R
      [--premises-json J | --premises-file F]
      [--evidence-json J | --evidence-file F]
      [--trace TRACE.jsonl] [--store DIR]
  verdict-path.py expand VERDICT_ID [--store DIR]
  verdict-path.py show VERDICT_ID [--store DIR]     # sin path tambien funciona
  verdict-path.py --validate VERDICT_ID [--trace F] [--store DIR]
Exit: 0 ok · 1 validacion FAIL (grounding/refs) · 2 uso/input invalido.
"""
import argparse
import json
import os
import sys

DEFAULT_STORE = "data/verdicts"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)


def _load_json_argument(json_arg, file_arg, kind):
    if json_arg:
        return json.loads(json_arg)
    if file_arg:
        with open(file_arg, encoding="utf-8") as f:
            return json.load(f)
    return []


def load_trace_events(trace_path):
    events = []
    if not trace_path or not os.path.exists(trace_path):
        return events
    with open(trace_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    events.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return events


def trace_observed(trace_events, trace_event, tool=None):
    for ev in trace_events:
        if ev.get("event") == trace_event:
            if tool is None or ev.get("tool") == tool:
                return True
    return False


def check_grounding(node, trace_events, errors, where):
    """L28 M2: ground:true exige trace_event observado (y tool si se declara)."""
    if not node.get("ground"):
        return
    te = node.get("trace_event")
    if not te:
        errors.append(f"{where}: ground:true sin trace_event")
        return
    if not trace_observed(trace_events, te, node.get("tool")):
        errors.append(
            f"{where}: trace_event '{te}'"
            + (f" tool '{node['tool']}'" if node.get("tool") else "")
            + " NO observado en el trace (grounding fallido)")


def check_refs(node, errors, warnings, where):
    ref = node.get("ref")
    if not ref or ref.startswith(("http://", "https://", "trace#", "verdict:")):
        return
    target = ref if os.path.isabs(ref) else os.path.join(REPO_ROOT, ref)
    if not os.path.exists(target):
        warnings.append(f"{where}: ref inexistente: {ref}")


def validate_path(path, trace_events):
    errors, warnings = [], []
    for i, p in enumerate(path.get("premises", [])):
        check_grounding(p, trace_events, errors, f"premise[{i}]")
        check_refs(p, errors, warnings, f"premise[{i}]")
    for i, e in enumerate(path.get("evidence", [])):
        if e.get("trace_event"):
            check_grounding(e, trace_events, errors, f"evidence[{i}]")
        else:
            check_refs(e, errors, warnings, f"evidence[{i}]")
    return errors, warnings


def store_path(store):
    return store if os.path.isabs(store) else os.path.join(REPO_ROOT, store)


def verdict_file(store, verdict_id):
    return os.path.join(store_path(store), f"{verdict_id}.json")


def save_verdict(store, verdict):
    os.makedirs(store_path(store), exist_ok=True)
    path = verdict_file(store, verdict["verdict_id"])
    with open(path, "w", encoding="utf-8") as f:
        f.write(json.dumps(verdict, ensure_ascii=False, indent=2) + "\n")
    return path


def load_stored(store, verdict_id):
    path = verdict_file(store, verdict_id)
    if not os.path.exists(path):
        raise ValueError(f"veredicto no encontrado: {path}")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def expand_chain(verdict, store, seen=None):
    seen = seen or set()
    if verdict["verdict_id"] in seen:
        return {"verdict_id": verdict["verdict_id"], "cycle": True}
    seen = seen | {verdict["verdict_id"]}
    path = verdict.get("path")
    if path is None:
        return {"verdict_id": verdict["verdict_id"], "path": None,
                "note": "sin path (veredicto consumible, sin derivacion)"}
    node = {
        "verdict_id": verdict["verdict_id"],
        "rule": path.get("rule"),
        "outcome": verdict.get("outcome"),
        "premises": [],
        "evidence": path.get("evidence", []),
    }
    for p in path.get("premises", []):
        entry = dict(p)
        ref = p.get("ref", "")
        if ref.startswith("verdict:"):
            sub_id = ref[len("verdict:"):]
            try:
                entry["sub_path"] = expand_chain(load_stored(store, sub_id), store, seen)
            except ValueError:
                entry["sub_path"] = {"verdict_id": sub_id, "error": "no encontrado"}
        node["premises"].append(entry)
    return node


def cmd_attach(args):
    with open(args.verdict_json, encoding="utf-8") as f:
        verdict = json.load(f)
    if "verdict_id" not in verdict:
        raise ValueError("el veredicto necesita verdict_id")
    premises = _load_json_argument(args.premises_json, args.premises_file, "premises")
    evidence = _load_json_argument(args.evidence_json, args.evidence_file, "evidence")
    if not isinstance(premises, list) or not isinstance(evidence, list):
        raise ValueError("premises y evidence deben ser arrays")
    if not args.rule:
        raise ValueError("attach exige --rule")
    trace_events = load_trace_events(args.trace)
    path = {"rule": args.rule, "premises": premises, "evidence": evidence}
    errors, warnings = validate_path(path, trace_events)
    for w in warnings:
        print(f"WARN: {w}", file=sys.stderr)
    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        return 1
    verdict["path"] = path
    out = save_verdict(args.store, verdict)
    print(json.dumps({"attached": verdict["verdict_id"], "file": out},
                     ensure_ascii=False))
    return 0


def cmd_expand(args):
    verdict = load_stored(args.store, args.verdict_id)
    print(json.dumps(expand_chain(verdict, args.store), ensure_ascii=False, indent=2))
    return 0


def cmd_show(args):
    verdict = load_stored(args.store, args.verdict_id)
    print(json.dumps(verdict, ensure_ascii=False, indent=2))
    return 0


def cmd_validate(args):
    verdict = load_stored(args.store, args.verdict_id)
    if verdict.get("path") is None:
        print(json.dumps({"validate": "OK", "verdict_id": verdict["verdict_id"],
                          "note": "sin path: consumible, nada que groundear"},
                         ensure_ascii=False))
        return 0
    trace_events = load_trace_events(args.trace)
    errors, warnings = validate_path(verdict["path"], trace_events)
    result = {"validate": "FAIL" if errors else "OK",
              "verdict_id": verdict["verdict_id"]}
    if warnings:
        result["warnings"] = warnings
    if errors:
        result["errors"] = errors
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if errors else 0


def main():
    # pre-scan: --store/--trace/--validate aceptados en cualquier posicion
    g_store, g_trace, g_validate, g_vid = DEFAULT_STORE, None, False, None
    rest = []
    argv = sys.argv[1:]
    i = 0
    while i < len(argv):
        if argv[i] == "--store":
            g_store = argv[i + 1]
            i += 2
        elif argv[i] == "--trace":
            g_trace = argv[i + 1]
            i += 2
        elif argv[i] == "--validate":
            g_validate = True
            nxt = argv[i + 1] if i + 1 < len(argv) else None
            if nxt is not None and not nxt.startswith("-") and \
               nxt not in ("attach", "expand", "show", "validate"):
                g_vid = nxt
                i += 2
            else:
                i += 1
        else:
            rest.append(argv[i])
            i += 1

    ap = argparse.ArgumentParser(description="SE-367 Derivation Path")
    sub = ap.add_subparsers(dest="cmd")

    p_att = sub.add_parser("attach")
    p_att.add_argument("verdict_json")
    p_att.add_argument("--rule")
    p_att.add_argument("--premises-json")
    p_att.add_argument("--premises-file")
    p_att.add_argument("--evidence-json")
    p_att.add_argument("--evidence-file")

    p_exp = sub.add_parser("expand")
    p_exp.add_argument("verdict_id")

    p_show = sub.add_parser("show")
    p_show.add_argument("verdict_id")

    p_val = sub.add_parser("validate")
    p_val.add_argument("verdict_id")

    args = ap.parse_args(rest)
    args.store = g_store
    args.trace = g_trace
    try:
        if g_validate:
            if g_vid is not None:
                args.verdict_id = g_vid
            elif args.cmd in (None, "attach") or not hasattr(args, "verdict_id"):
                ap.error("--validate exige VERDICT_ID")
            sys.exit(cmd_validate(args))
        if args.cmd == "attach":
            sys.exit(cmd_attach(args))
        if args.cmd == "expand":
            sys.exit(cmd_expand(args))
        if args.cmd == "show":
            sys.exit(cmd_show(args))
        if args.cmd == "validate":
            sys.exit(cmd_validate(args))
        ap.print_help()
        sys.exit(2)
    except (ValueError, OSError, json.JSONDecodeError, KeyError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
