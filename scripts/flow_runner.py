#!/usr/bin/env python3
"""flow_runner.py — Slice 2 of SPEC-AGENTIC-FLOW-GRAPH.

Sequential executor for `kind: command` and `kind: skill` nodes.
- State is namespaced (flow:/runtime:/meta:); nodes only see/write `flow:`.
- Edges with `when` are evaluated via celpy after each node.
- Trace is appended to output/flows/{run_id}/trace.jsonl.
- Idempotent caching by input hash when `idempotent: true` (Slice 4 will extend).

Slice 2 scope:
- kind=command: invokes `/{name}` via subprocess of `claude` CLI?  No, in this
  bootstrap we just record an "invoked" event and accept patches via stdout JSON.
  For the hello-world smoke test we shell out to `echo` to keep tests hermetic.
- kind=skill: imports `scripts/lib/skills/<name>.py` and calls `run(args, state)`.
- kind=agent / hook / subflow: deferred to Slice 3/4.
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import time
import uuid
import shlex
import shutil
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any

try:
    import yaml
    import celpy
    from celpy import celtypes
except ImportError as e:
    print(f"ERROR: missing dep ({e}). Run: source scripts/savia-env.sh", file=sys.stderr)
    sys.exit(3)

REPO_ROOT = Path(__file__).resolve().parent.parent
FLOWS_DIR = REPO_ROOT / ".scm" / "flows"
OUTPUT_DIR = REPO_ROOT / "output" / "flows"
CACHE_DIR = OUTPUT_DIR / "_cache"
SKILLS_LIB = REPO_ROOT / "scripts" / "lib" / "skills"

NAMESPACES = ("flow", "runtime", "meta")
MAX_SUBFLOW_DEPTH = 3
SUBFLOW_DEPTH_ENV = "_SAVIA_SUBFLOW_DEPTH"


class StateError(RuntimeError):
    pass


class FlowState:
    """Three-namespace shared state. Nodes only see/write `flow:` keys without prefix."""

    def __init__(self, initial_flow: dict):
        self._data = {"flow": dict(initial_flow), "runtime": {}, "meta": {}}

    def view_for_node(self) -> dict:
        return dict(self._data["flow"])

    def apply_patch_from_node(self, patch: dict) -> None:
        if not isinstance(patch, dict):
            raise StateError(f"node patch must be dict, got {type(patch).__name__}")
        for k in patch:
            for ns in NAMESPACES:
                if k.startswith(f"{ns}:"):
                    raise StateError(f"node attempted cross-namespace write: {k!r}")
        self._data["flow"].update(patch)

    def write_runtime(self, key: str, value: Any) -> None:
        self._data["runtime"][key] = value

    def cel_context(self, nodes_outputs: dict) -> dict:
        return {
            "state": celtypes.MapType(self._data["flow"]),
            "nodes": celtypes.MapType({k: celtypes.MapType(v) for k, v in nodes_outputs.items()}),
        }

    def snapshot(self) -> dict:
        return json.loads(json.dumps(self._data))


def topo_order(nodes: list[dict], edges: list[dict]) -> list[str]:
    node_ids = [n["id"] for n in nodes]
    incoming: dict[str, set[str]] = {nid: set() for nid in node_ids}
    outgoing: dict[str, list[str]] = {nid: [] for nid in node_ids}
    for n in nodes:
        for dep in n.get("depends_on", []):
            incoming[n["id"]].add(dep)
            outgoing[dep].append(n["id"])
    for e in edges:
        targets = e["to"] if isinstance(e["to"], list) else [e["to"]]
        for t in targets:
            if t == "END":
                continue
            incoming[t].add(e["from"])
            outgoing[e["from"]].append(t)
    order: list[str] = []
    ready = [nid for nid in node_ids if not incoming[nid]]
    while ready:
        ready.sort()  # deterministic
        nid = ready.pop(0)
        order.append(nid)
        for child in outgoing[nid]:
            incoming[child].discard(nid)
            if not incoming[child] and child not in order and child not in ready:
                ready.append(child)
    if len(order) != len(node_ids):
        raise StateError(f"topological order incomplete: {set(node_ids) - set(order)}")
    return order


def hash_inputs(args: dict, flow_view: dict) -> str:
    payload = json.dumps({"args": args, "state": flow_view}, sort_keys=True).encode()
    return hashlib.sha256(payload).hexdigest()[:16]


def execute_command(node: dict, state: FlowState) -> dict:
    """Slice 3: bridge to .opencode/commands/{name}.md.

    Slash commands in OpenCode are markdown prompts, not directly executable
    from a script context. We honour two execution modes:
      1) If the command file declares an `exec:` shell line in frontmatter, run it.
      2) Otherwise we record an "invoked" event (stub for human/agent runtime).
    Args are passed via env var FLOW_NODE_ARGS as JSON.
    """
    name = node["invoke"].lstrip("/")
    args = node.get("args", {})
    cmd_file = REPO_ROOT / ".opencode" / "commands" / f"{name}.md"
    if not cmd_file.exists():
        return {"_invoked": f"command:{name}", "_args": args, "_status": "not_found"}
    # Look for frontmatter `exec:` directive (Slice 3 minimal bridge)
    head = cmd_file.read_text().split("---")
    exec_line = None
    if len(head) >= 3:
        for line in head[1].splitlines():
            line = line.strip()
            if line.startswith("exec:"):
                # Take everything after "exec:" verbatim. Quotes are part of
                # the shell command and must reach shlex intact.
                exec_line = line[len("exec:"):].strip()
                break
    if exec_line:
        env = os.environ.copy()
        env["FLOW_NODE_ARGS"] = json.dumps(args)
        proc = subprocess.run(
            shlex.split(exec_line), capture_output=True, text=True, env=env, timeout=60
        )
        if proc.returncode != 0:
            raise StateError(f"command {name} failed: {proc.stderr.strip()}")
        try:
            return json.loads(proc.stdout) if proc.stdout.strip() else {"_invoked": f"command:{name}"}
        except json.JSONDecodeError:
            return {"_invoked": f"command:{name}", "_stdout": proc.stdout.strip()[:500]}
    return {"_invoked": f"command:{name}", "_args": args, "_status": "noexec"}


def execute_skill(node: dict, state: FlowState) -> dict:
    skill_name = node["invoke"]
    py = SKILLS_LIB / f"{skill_name}.py"
    if not py.exists():
        raise StateError(f"skill not found: {py}")
    spec = importlib.util.spec_from_file_location(f"skill_{skill_name}", py)
    if spec is None or spec.loader is None:
        raise StateError(f"could not load skill: {py}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    if not hasattr(mod, "run"):
        raise StateError(f"skill {skill_name} missing run(args, state) function")
    return mod.run(node.get("args", {}), state.view_for_node())


def execute_agent(node: dict, state: FlowState) -> dict:
    """Slice 3: agent invocation stub.

    Real agents in OpenCode are invoked through the Task tool, which is a
    runtime capability of Claude/OpenCode itself, not callable from a script.
    For the runner we record the invocation and return a deterministic stub
    output so flows can be exercised end-to-end in tests. A future slice will
    bridge to the live Task tool when run inside the agent runtime.
    """
    name = node["invoke"]
    args = node.get("args", {})
    agent_file = REPO_ROOT / ".opencode" / "agents" / f"{name}.md"
    if not agent_file.exists():
        return {"_invoked": f"agent:{name}", "_args": args, "_status": "not_found"}
    # Deterministic stub: echo args + agent name. Tests assert on these fields.
    return {"_invoked": f"agent:{name}", "_args": args, "_status": "stub"}


def execute_hook(node: dict, state: FlowState) -> dict:
    """Slice 3: exec a hook from .opencode/hooks/{name}.sh directly.

    Hooks run with FLOW_NODE_ARGS in env. They MUST print JSON to stdout if
    they want to contribute outputs/state. Non-zero exit is a hard failure.
    """
    name = node["invoke"]
    args = node.get("args", {})
    hook_file = REPO_ROOT / ".opencode" / "hooks" / f"{name}.sh"
    if not hook_file.exists():
        raise StateError(f"hook not found: {hook_file}")
    if not os.access(hook_file, os.X_OK):
        raise StateError(f"hook not executable: {hook_file}")
    env = os.environ.copy()
    env["FLOW_NODE_ARGS"] = json.dumps(args)
    proc = subprocess.run(
        [str(hook_file)], capture_output=True, text=True, env=env, timeout=60
    )
    if proc.returncode != 0:
        raise StateError(f"hook {name} failed (exit {proc.returncode}): {proc.stderr.strip()[:300]}")
    if not proc.stdout.strip():
        return {"_invoked": f"hook:{name}", "_status": "ok"}
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return {"_invoked": f"hook:{name}", "_stdout": proc.stdout.strip()[:500]}


def execute_subflow(node: dict, state: FlowState) -> dict:
    """Slice 4: invoke another .flow.yaml. Depth-limited via env var.

    The subflow runs in a fresh FlowState seeded with `node.args`. Its final
    `flow:` namespace is returned as outputs so parent edges can reference it.
    """
    depth = int(os.environ.get(SUBFLOW_DEPTH_ENV, "0"))
    if depth >= MAX_SUBFLOW_DEPTH:
        raise StateError(
            f"subflow depth limit exceeded: {depth} >= {MAX_SUBFLOW_DEPTH} "
            f"(node={node['id']}, invoke={node['invoke']})"
        )
    target = node["invoke"]
    if not target.endswith(".flow.yaml"):
        target_path = FLOWS_DIR / f"{target}.flow.yaml"
    else:
        target_path = Path(target)
        if not target_path.is_absolute():
            target_path = FLOWS_DIR / target_path
    if not target_path.exists():
        raise StateError(f"subflow not found: {target_path}")
    inputs = node.get("args", {}) or {}
    # Recurse with depth+1 in env so nested subflows enforce the limit.
    prev = os.environ.get(SUBFLOW_DEPTH_ENV)
    os.environ[SUBFLOW_DEPTH_ENV] = str(depth + 1)
    try:
        result = run_flow(target_path, inputs, dry_run=False)
    finally:
        if prev is None:
            os.environ.pop(SUBFLOW_DEPTH_ENV, None)
        else:
            os.environ[SUBFLOW_DEPTH_ENV] = prev
    if not result.get("ok", False):
        raise StateError(f"subflow {target} failed: {result.get('reason', 'unknown')}")
    # Read final state and surface flow: namespace as outputs
    state_file = result.get("state")
    sub_state = {}
    if state_file and Path(state_file).exists():
        try:
            sub_state = json.loads(Path(state_file).read_text()).get("flow", {})
        except Exception:
            sub_state = {}
    return {
        "_invoked": f"subflow:{target}",
        "_subflow_run_id": result.get("run_id"),
        "_subflow_depth": depth + 1,
        "outputs": sub_state,
    }


def cache_path_for(node_id: str, args: dict, view: dict) -> Path:
    h = hash_inputs({"node": node_id, "args": args}, view)
    return CACHE_DIR / f"{h}.json"


def dispatch_node(node: dict, state: FlowState) -> dict:
    kind = node["kind"]
    if kind == "command":
        return execute_command(node, state)
    if kind == "skill":
        return execute_skill(node, state)
    if kind == "agent":
        return execute_agent(node, state)
    if kind == "hook":
        return execute_hook(node, state)
    if kind == "subflow":
        return execute_subflow(node, state)
    raise StateError(f"unknown kind: {kind}")


def evaluate_edge(expr: str, state: FlowState, nodes_outputs: dict, env: celpy.Environment) -> bool:
    ast = env.compile(expr)
    prog = env.program(ast)
    result = prog.evaluate(state.cel_context(nodes_outputs))
    return bool(result)


def run_flow(flow_path: Path, inputs: dict, dry_run: bool = False) -> dict:
    flow = yaml.safe_load(flow_path.read_text())
    flow_id = flow["flow_id"]
    run_id = dt.datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:6]
    run_dir = OUTPUT_DIR / run_id
    run_dir.mkdir(parents=True, exist_ok=True)
    trace_path = run_dir / "trace.jsonl"

    nodes_by_id = {n["id"]: n for n in flow["nodes"]}
    state = FlowState(flow.get("state", {}))
    state.write_runtime("flow_id", flow_id)
    state.write_runtime("run_id", run_id)
    state.write_runtime("inputs", inputs)
    nodes_outputs: dict[str, dict] = {}
    env = celpy.Environment()

    order = topo_order(flow["nodes"], flow["edges"])

    if dry_run:
        return {"flow_id": flow_id, "run_id": run_id, "order": order, "dry_run": True}

    def emit(event: dict) -> None:
        event["ts"] = dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")
        with trace_path.open("a") as f:
            f.write(json.dumps(event) + "\n")

    emit({"event": "flow_start", "flow_id": flow_id, "run_id": run_id, "inputs": inputs})

    started = time.time()
    max_duration = flow["guards"]["max_duration_minutes"] * 60

    # Slice 3: build waves. Consecutive nodes in topo order sharing the same
    # parallel_group are executed concurrently. Singletons execute sequentially.
    waves: list[list[str]] = []
    cur: list[str] = []
    cur_group: str | None = None
    for nid in order:
        g = nodes_by_id[nid].get("parallel_group")
        if g is not None and g == cur_group:
            cur.append(nid)
        else:
            if cur:
                waves.append(cur)
            cur = [nid]
            cur_group = g
    if cur:
        waves.append(cur)

    def run_one(nid: str) -> tuple[str, dict, float, str | None, bool]:
        node = nodes_by_id[nid]
        t0 = time.time()
        cache_used = False
        try:
            if node.get("idempotent", False):
                cp = cache_path_for(nid, node.get("args", {}), state.view_for_node())
                if cp.exists():
                    try:
                        cached = json.loads(cp.read_text())
                        return nid, cached, time.time() - t0, None, True
                    except Exception:
                        pass  # fall through to fresh exec
            outputs = dispatch_node(node, state)
        except Exception as e:
            return nid, {}, time.time() - t0, str(e), False
        if not isinstance(outputs, dict):
            outputs = {"_result": outputs}
        if node.get("idempotent", False):
            try:
                cp = cache_path_for(nid, node.get("args", {}), state.view_for_node())
                CACHE_DIR.mkdir(parents=True, exist_ok=True)
                cp.write_text(json.dumps(outputs, default=str))
            except Exception:
                pass
        return nid, outputs, time.time() - t0, None, cache_used

    for wave in waves:
        if time.time() - started > max_duration:
            emit({"event": "flow_abort", "reason": "max_duration_exceeded"})
            return {"flow_id": flow_id, "run_id": run_id, "ok": False, "reason": "timeout"}

        for nid in wave:
            emit({"event": "node_start", "node": nid, "kind": nodes_by_id[nid]["kind"],
                  "parallel_group": nodes_by_id[nid].get("parallel_group")})

        if len(wave) == 1:
            results = [run_one(wave[0])]
        else:
            emit({"event": "wave_start", "nodes": wave,
                  "parallel_group": nodes_by_id[wave[0]].get("parallel_group")})
            results = []
            with ThreadPoolExecutor(max_workers=min(len(wave), 8)) as ex:
                futs = {ex.submit(run_one, nid): nid for nid in wave}
                for fut in as_completed(futs):
                    results.append(fut.result())
            # preserve wave order in results for trace determinism
            results.sort(key=lambda r: wave.index(r[0]))
            emit({"event": "wave_end", "nodes": wave})

        for nid, outputs, dur, err, cache_hit in results:
            if err is not None:
                emit({"event": "node_error", "node": nid, "error": err})
                return {"flow_id": flow_id, "run_id": run_id, "ok": False,
                        "reason": f"node {nid} failed: {err}"}
            if cache_hit:
                emit({"event": "node_cache_hit", "node": nid})
            nodes_outputs[nid] = outputs
            patch = outputs.pop("_state_patch", None)
            if patch:
                state.apply_patch_from_node(patch)
            emit({"event": "node_end", "node": nid, "outputs": outputs,
                  "duration_s": round(dur, 4), "cache_hit": cache_hit})

        # Evaluate outgoing edges of every node in the wave
        for nid, _, _, _, _ in results:
            for edge in flow["edges"]:
                if edge["from"] != nid:
                    continue
                cond = edge.get("when")
                if cond is not None:
                    try:
                        chosen = evaluate_edge(cond, state, nodes_outputs, env)
                    except Exception as e:
                        emit({"event": "edge_error",
                              "edge": f"{edge['from']}->{edge['to']}", "error": str(e)})
                        chosen = False
                else:
                    chosen = True
                emit({"event": "edge_eval", "from": edge["from"], "to": edge["to"],
                      "when": cond, "chosen": chosen})

    emit({"event": "flow_end", "ok": True, "duration_s": round(time.time() - started, 4)})

    final_state = run_dir / "state.json"
    final_state.write_text(json.dumps(state.snapshot(), indent=2))
    return {"flow_id": flow_id, "run_id": run_id, "ok": True, "trace": str(trace_path), "state": str(final_state)}


def parse_inputs(pairs: list[str]) -> dict:
    out: dict = {}
    for kv in pairs or []:
        if "=" not in kv:
            raise SystemExit(f"--input expects key=value, got {kv!r}")
        k, v = kv.split("=", 1)
        try:
            out[k] = json.loads(v)
        except json.JSONDecodeError:
            out[k] = v
    return out


def _maybe_export_otel(trace_path: str) -> None:
    """Invoca el exporter OTel si SAVIA_OTEL_ENABLED=true (SPEC-FLOW-OBSERVABILITY §2.4).

    Fallo del exporter nunca interrumpe el flujo (D-1, D-3). Si Python no tiene
    las dependencias OTel instaladas, el error se registra en stderr y se continúa.
    """
    if os.environ.get("SAVIA_OTEL_ENABLED", "").lower() != "true":
        return
    exporter_script = REPO_ROOT / "scripts" / "lib" / "otel_exporter.py"
    if not exporter_script.exists():
        return
    try:
        import subprocess as _sp
        _sp.run(
            [sys.executable, str(exporter_script), "--trace-file", trace_path],
            check=False,
            timeout=15,
        )
    except Exception as exc:  # noqa: BLE001
        print(f"⚠ OTel export falló (no crítico): {exc}", file=sys.stderr)


def cmd_run(args) -> int:
    p = Path(args.flow)
    if not p.exists():
        p = FLOWS_DIR / f"{args.flow}.flow.yaml"
    if not p.exists():
        print(f"ERROR: flow not found: {args.flow}", file=sys.stderr)
        return 3
    inputs = parse_inputs(args.input)
    result = run_flow(p, inputs, dry_run=args.dry_run)
    print(json.dumps(result, indent=2))
    if not args.dry_run and result.get("trace"):
        _maybe_export_otel(result["trace"])
    return 0 if result.get("ok") or result.get("dry_run") else 1


def cmd_trace(args) -> int:
    if args.run:
        run_dir = OUTPUT_DIR / args.run
    else:
        candidates = sorted(OUTPUT_DIR.glob(f"*"))
        candidates = [c for c in candidates if c.is_dir() and c.name != "_cache"]
        if not candidates:
            print("no runs found", file=sys.stderr)
            return 3
        run_dir = candidates[-1]
    trace = run_dir / "trace.jsonl"
    if not trace.exists():
        print(f"no trace at {trace}", file=sys.stderr)
        return 3
    for line in trace.read_text().splitlines():
        ev = json.loads(line)
        if args.node and ev.get("node") != args.node:
            continue
        print(json.dumps(ev))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Agentic Flow Graph runner")
    sub = parser.add_subparsers(dest="cmd", required=True)
    pr = sub.add_parser("run", help="Execute a flow")
    pr.add_argument("flow", help="flow_id or path to .flow.yaml")
    pr.add_argument("--input", action="append", help="key=value (JSON or string)")
    pr.add_argument("--dry-run", action="store_true")
    pt = sub.add_parser("trace", help="Print trace of a run")
    pt.add_argument("--run", help="run_id (default: latest)")
    pt.add_argument("--node", help="filter by node id")
    args = parser.parse_args()
    if args.cmd == "run":
        return cmd_run(args)
    if args.cmd == "trace":
        return cmd_trace(args)
    return 3


if __name__ == "__main__":
    sys.exit(main())
