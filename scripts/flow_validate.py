#!/usr/bin/env python3
"""flow_validate.py — SPEC-AGENTIC-FLOW-GRAPH §2.7 + AMENDMENT-01.

Validates .scm/flows/*.flow.yaml against schemas/flow.schema.json AND
performs semantic checks: node references, acyclicity (unless guarded),
CEL compile-time check on every `when` and `exit_when` expression.

Exit codes:
  0  valid
  1  schema or semantic error
  2  CEL compile error
  3  I/O / usage error
"""
from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: pyyaml not available. Run: source scripts/savia-env.sh", file=sys.stderr)
    sys.exit(3)

try:
    import jsonschema
except ImportError:
    print("ERROR: jsonschema not available. Run: source scripts/savia-env.sh", file=sys.stderr)
    sys.exit(3)

try:
    import celpy
    from celpy import celtypes
except ImportError:
    print("ERROR: celpy (cel-python) not available. Run: source scripts/savia-env.sh", file=sys.stderr)
    sys.exit(3)


REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = REPO_ROOT / "schemas" / "flow.schema.json"
FLOWS_DIR = REPO_ROOT / ".scm" / "flows"


def load_schema() -> dict:
    with SCHEMA_PATH.open() as f:
        return json.load(f)


def load_flow(path: Path) -> dict:
    with path.open() as f:
        return yaml.safe_load(f)


def validate_schema(flow: dict, schema: dict) -> list[str]:
    errs: list[str] = []
    validator = jsonschema.Draft202012Validator(schema)
    for err in sorted(validator.iter_errors(flow), key=lambda e: list(e.absolute_path)):
        loc = "/".join(str(p) for p in err.absolute_path) or "<root>"
        errs.append(f"schema[{loc}]: {err.message}")
    return errs


def validate_filename(flow: dict, path: Path) -> list[str]:
    expected = path.name.removesuffix(".flow.yaml")
    flow_id = flow.get("flow_id", "")
    if expected != flow_id:
        return [f"filename mismatch: file={expected} flow_id={flow_id}"]
    return []


def validate_node_refs(flow: dict) -> list[str]:
    errs: list[str] = []
    node_ids = {n["id"] for n in flow.get("nodes", [])}
    if len(node_ids) != len(flow.get("nodes", [])):
        errs.append("duplicate node id")
    for node in flow.get("nodes", []):
        for dep in node.get("depends_on", []):
            if dep not in node_ids:
                errs.append(f"node[{node['id']}].depends_on references unknown node: {dep}")
    for edge in flow.get("edges", []):
        if edge["from"] not in node_ids:
            errs.append(f"edge.from references unknown node: {edge['from']}")
        targets = edge["to"] if isinstance(edge["to"], list) else [edge["to"]]
        for t in targets:
            if t != "END" and t not in node_ids:
                errs.append(f"edge.to references unknown node: {t}")
    return errs


def validate_acyclic(flow: dict) -> list[str]:
    """Detect cycles in the unconditional edge graph. Cycles ARE allowed if
    every cycle node has an `exit_when` guard."""
    nodes = {n["id"]: n for n in flow.get("nodes", [])}
    adj: dict[str, list[str]] = {nid: [] for nid in nodes}
    for edge in flow.get("edges", []):
        targets = edge["to"] if isinstance(edge["to"], list) else [edge["to"]]
        for t in targets:
            if t == "END":
                continue
            adj.setdefault(edge["from"], []).append(t)

    # Tarjan-style DFS for cycle detection
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {nid: WHITE for nid in nodes}
    cycles: list[list[str]] = []

    def dfs(u: str, stack: list[str]) -> None:
        color[u] = GRAY
        stack.append(u)
        for v in adj.get(u, []):
            if color[v] == GRAY:
                idx = stack.index(v)
                cycles.append(stack[idx:] + [v])
            elif color[v] == WHITE:
                dfs(v, stack)
        stack.pop()
        color[u] = BLACK

    for nid in nodes:
        if color[nid] == WHITE:
            dfs(nid, [])

    errs: list[str] = []
    for cycle in cycles:
        cycle_nodes = set(cycle)
        unguarded = [c for c in cycle_nodes if not nodes[c].get("exit_when")]
        if unguarded:
            errs.append(f"cycle without exit_when guard: {' -> '.join(cycle)} (unguarded: {unguarded})")
    return errs


def validate_cel(flow: dict) -> list[str]:
    """Compile every `when` (edges) and `exit_when` (nodes) via celpy.
    Type must compile to bool. AMENDMENT-01."""
    errs: list[str] = []
    env = celpy.Environment()

    def compile_expr(expr: str, location: str) -> None:
        try:
            ast = env.compile(expr)
            prog = env.program(ast)
            # Smoke-eval with empty context to detect parse-only success vs runtime
            try:
                result = prog.evaluate({"state": celtypes.MapType({}), "nodes": celtypes.MapType({})})
                if not isinstance(result, (bool, celtypes.BoolType)):
                    errs.append(f"CEL[{location}]: expression must return bool, got {type(result).__name__}: {expr!r}")
            except Exception:
                # Runtime failures with empty context are acceptable (missing keys etc).
                # Compile-time success is what AMENDMENT-01 requires.
                pass
        except Exception as e:
            errs.append(f"CEL[{location}]: compile error: {e}: {expr!r}")

    for edge in flow.get("edges", []):
        if "when" in edge:
            compile_expr(edge["when"], f"edge {edge['from']}->{edge['to']}")
    for node in flow.get("nodes", []):
        if "exit_when" in node:
            compile_expr(node["exit_when"], f"node[{node['id']}].exit_when")
    return errs


def validate_one(path: Path, schema: dict) -> tuple[bool, list[str]]:
    try:
        flow = load_flow(path)
    except yaml.YAMLError as e:
        return False, [f"yaml parse error: {e}"]
    if not isinstance(flow, dict):
        return False, ["root must be a mapping"]
    errs: list[str] = []
    errs.extend(validate_schema(flow, schema))
    if errs:
        return False, errs
    errs.extend(validate_filename(flow, path))
    errs.extend(validate_node_refs(flow))
    errs.extend(validate_acyclic(flow))
    errs.extend(validate_cel(flow))
    return (len(errs) == 0), errs


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Agentic Flow Graph YAML files")
    parser.add_argument("target", help="flow_id, path, or 'all'")
    parser.add_argument("--json", action="store_true", help="emit JSON report")
    args = parser.parse_args()

    if not SCHEMA_PATH.exists():
        print(f"ERROR: schema not found at {SCHEMA_PATH}", file=sys.stderr)
        return 3
    schema = load_schema()

    paths: list[Path]
    if args.target == "all":
        paths = sorted(FLOWS_DIR.glob("*.flow.yaml"))
        if not paths:
            print(f"no flows in {FLOWS_DIR}", file=sys.stderr)
            return 0
    else:
        p = Path(args.target)
        if not p.exists():
            p = FLOWS_DIR / f"{args.target}.flow.yaml"
        if not p.exists():
            print(f"ERROR: flow not found: {args.target}", file=sys.stderr)
            return 3
        paths = [p]

    report = {"flows": [], "ok": True}
    cel_failed = False
    for path in paths:
        ok, errs = validate_one(path, schema)
        report["flows"].append({"path": str(path.relative_to(REPO_ROOT)), "ok": ok, "errors": errs})
        if not ok:
            report["ok"] = False
            if any(e.startswith("CEL[") for e in errs):
                cel_failed = True

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        for entry in report["flows"]:
            mark = "OK" if entry["ok"] else "FAIL"
            print(f"[{mark}] {entry['path']}")
            for e in entry["errors"]:
                print(f"   - {e}")
        if not report["ok"]:
            print(f"\n{sum(1 for f in report['flows'] if not f['ok'])} flow(s) failed")

    if not report["ok"]:
        return 2 if cel_failed else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
