"""Tests for scripts/flow_runner.py — Slice 2 of SPEC-AGENTIC-FLOW-GRAPH."""
from __future__ import annotations
import json
import subprocess
import sys
from pathlib import Path
import yaml

REPO = Path(__file__).resolve().parents[2]
RUNNER = REPO / "scripts" / "flow_runner.py"
HELLO = REPO / ".scm" / "flows" / "hello-world.flow.yaml"


def run_cli(*args: str) -> tuple[int, str, str]:
    proc = subprocess.run([sys.executable, str(RUNNER), *args], cwd=REPO,
                          capture_output=True, text=True)
    return proc.returncode, proc.stdout, proc.stderr


def parse_json_stdout(out: str) -> dict:
    return json.loads(out)


def test_hello_world_runs_and_emits_trace():
    rc, out, err = run_cli("run", "hello-world")
    assert rc == 0, err
    payload = parse_json_stdout(out)
    assert payload["ok"] is True
    trace = Path(payload["trace"])
    assert trace.exists()
    events = [json.loads(line) for line in trace.read_text().splitlines()]
    kinds = [e["event"] for e in events]
    assert kinds[0] == "flow_start"
    assert kinds[-1] == "flow_end"
    assert "node_start" in kinds and "node_end" in kinds
    assert any(e["event"] == "edge_eval" and e["chosen"] is True for e in events)


def test_dry_run_returns_topo_order_only():
    rc, out, err = run_cli("run", "hello-world", "--dry-run")
    assert rc == 0, err
    payload = parse_json_stdout(out)
    assert payload["dry_run"] is True
    assert payload["order"] == ["say-hello"]


def test_unknown_flow_returns_3():
    rc, _, err = run_cli("run", "no-such-flow")
    assert rc == 3
    assert "not found" in err.lower()


def test_state_namespace_isolation_runtime_invisible_to_skills(tmp_path):
    """Build a flow with a single skill node that returns the state it sees.
    The runtime: namespace must NOT leak into the skill's view."""
    flow = {
        "flow_id": "skill-state-vis",
        "version": 1,
        "confidentiality": "N1",
        "state": {"foo": "bar"},
        "nodes": [{"id": "echo", "kind": "skill", "invoke": "echo_skill"}],
        "edges": [{"from": "echo", "to": "END"}],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    flow_path = REPO / ".scm" / "flows" / "skill-state-vis.flow.yaml"
    flow_path.write_text(yaml.safe_dump(flow))
    try:
        rc, out, err = run_cli("run", "skill-state-vis")
        assert rc == 0, err
        payload = parse_json_stdout(out)
        trace = Path(payload["trace"])
        events = [json.loads(line) for line in trace.read_text().splitlines()]
        node_end = next(e for e in events if e["event"] == "node_end")
        state_seen = node_end["outputs"]["state_seen"]
        # The skill must see flow:foo as plain "foo", and must NOT see runtime: keys.
        assert state_seen == {"foo": "bar"}, state_seen
        # State file holds all 3 namespaces (runtime visible to motor only).
        final_state = json.loads(Path(payload["state"]).read_text())
        assert set(final_state.keys()) == {"flow", "runtime", "meta"}
        assert final_state["runtime"]["flow_id"] == "skill-state-vis"
    finally:
        flow_path.unlink(missing_ok=True)


def test_skill_state_patch_applied(tmp_path):
    """A skill returning _state_patch mutates flow state for downstream nodes."""
    flow = {
        "flow_id": "patch-applies",
        "version": 1,
        "confidentiality": "N1",
        "state": {"count": 0},
        "nodes": [
            {"id": "inc1", "kind": "skill", "invoke": "counter_skill", "args": {"step": 5}},
            {"id": "inc2", "kind": "skill", "invoke": "counter_skill", "args": {"step": 3}, "depends_on": ["inc1"]},
        ],
        "edges": [
            {"from": "inc1", "to": "inc2"},
            {"from": "inc2", "to": "END"},
        ],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    flow_path = REPO / ".scm" / "flows" / "patch-applies.flow.yaml"
    flow_path.write_text(yaml.safe_dump(flow))
    try:
        rc, out, err = run_cli("run", "patch-applies")
        assert rc == 0, err
        payload = parse_json_stdout(out)
        final_state = json.loads(Path(payload["state"]).read_text())
        assert final_state["flow"]["count"] == 8, final_state
    finally:
        flow_path.unlink(missing_ok=True)


def test_edge_when_false_is_recorded(tmp_path):
    flow = {
        "flow_id": "edge-false",
        "version": 1,
        "confidentiality": "N1",
        "state": {"flag": 0},
        "nodes": [{"id": "a", "kind": "skill", "invoke": "echo_skill"}],
        "edges": [
            {"from": "a", "to": "END", "when": "state.flag == 1"},
        ],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    flow_path = REPO / ".scm" / "flows" / "edge-false.flow.yaml"
    flow_path.write_text(yaml.safe_dump(flow))
    try:
        rc, out, err = run_cli("run", "edge-false")
        assert rc == 0, err
        payload = parse_json_stdout(out)
        trace = [json.loads(l) for l in Path(payload["trace"]).read_text().splitlines()]
        edge_evals = [e for e in trace if e["event"] == "edge_eval"]
        assert len(edge_evals) == 1
        assert edge_evals[0]["chosen"] is False
    finally:
        flow_path.unlink(missing_ok=True)


def test_trace_subcommand_filters_by_node():
    # Run something first to have a trace.
    run_cli("run", "hello-world")
    rc, out, _ = run_cli("trace", "--node", "say-hello")
    assert rc == 0
    lines = [json.loads(l) for l in out.strip().splitlines()]
    assert all(e.get("node") == "say-hello" for e in lines)
    assert any(e["event"] == "node_start" for e in lines)


def test_topo_respects_depends_on(tmp_path):
    flow = {
        "flow_id": "topo-check",
        "version": 1,
        "confidentiality": "N1",
        "nodes": [
            {"id": "z", "kind": "skill", "invoke": "echo_skill", "depends_on": ["a", "m"]},
            {"id": "m", "kind": "skill", "invoke": "echo_skill", "depends_on": ["a"]},
            {"id": "a", "kind": "skill", "invoke": "echo_skill"},
        ],
        "edges": [
            {"from": "a", "to": "m"},
            {"from": "m", "to": "z"},
            {"from": "z", "to": "END"},
        ],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    flow_path = REPO / ".scm" / "flows" / "topo-check.flow.yaml"
    flow_path.write_text(yaml.safe_dump(flow))
    try:
        rc, out, err = run_cli("run", "topo-check", "--dry-run")
        assert rc == 0, err
        payload = parse_json_stdout(out)
        order = payload["order"]
        assert order.index("a") < order.index("m") < order.index("z"), order
    finally:
        flow_path.unlink(missing_ok=True)



# ─────────────────────────────────────────────────────────────────────────────
# Slice 3 — parallel_group, agent stub, hook exec, command bridge
# ─────────────────────────────────────────────────────────────────────────────


def test_parallel_group_emits_wave_events_and_runs_concurrently(tmp_path):
    """Three skills with same parallel_group execute in one wave.

    Each node writes a distinct key to avoid last-write-wins races —
    in a parallel wave, nodes read the SAME pre-wave snapshot, so
    overlapping keys are racy by spec design.
    """
    flow = {
        "flow_id": "parallel-skills",
        "version": 1,
        "confidentiality": "N1",
        "state": {"a": 0, "b": 0, "c": 0},
        "nodes": [
            {"id": "j1", "kind": "skill", "invoke": "set_key_skill",
             "args": {"key": "a", "value": 1}, "parallel_group": "judges"},
            {"id": "j2", "kind": "skill", "invoke": "set_key_skill",
             "args": {"key": "b", "value": 2}, "parallel_group": "judges"},
            {"id": "j3", "kind": "skill", "invoke": "set_key_skill",
             "args": {"key": "c", "value": 4}, "parallel_group": "judges"},
        ],
        "edges": [
            {"from": "j1", "to": "END"},
            {"from": "j2", "to": "END"},
            {"from": "j3", "to": "END"},
        ],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    flow_path = REPO / ".scm" / "flows" / "parallel-skills.flow.yaml"
    flow_path.write_text(yaml.safe_dump(flow))
    try:
        rc, out, err = run_cli("run", "parallel-skills")
        assert rc == 0, err
        payload = parse_json_stdout(out)
        trace = [json.loads(line) for line in Path(payload["trace"]).read_text().splitlines()]
        wave_starts = [e for e in trace if e["event"] == "wave_start"]
        wave_ends = [e for e in trace if e["event"] == "wave_end"]
        assert len(wave_starts) == 1, trace
        assert len(wave_ends) == 1
        assert set(wave_starts[0]["nodes"]) == {"j1", "j2", "j3"}
        assert wave_starts[0]["parallel_group"] == "judges"
        final_state = json.loads(Path(payload["state"]).read_text())
        assert final_state["flow"]["a"] == 1
        assert final_state["flow"]["b"] == 2
        assert final_state["flow"]["c"] == 4
    finally:
        flow_path.unlink(missing_ok=True)


def test_agent_kind_records_invocation_stub(tmp_path):
    """kind=agent records invocation; works even if agent file is real."""
    flow = {
        "flow_id": "agent-stub",
        "version": 1,
        "confidentiality": "N1",
        "state": {},
        "nodes": [
            {"id": "rev", "kind": "agent", "invoke": "code-reviewer", "args": {"pr": 42}},
        ],
        "edges": [{"from": "rev", "to": "END"}],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    flow_path = REPO / ".scm" / "flows" / "agent-stub.flow.yaml"
    flow_path.write_text(yaml.safe_dump(flow))
    try:
        rc, out, err = run_cli("run", "agent-stub")
        assert rc == 0, err
        payload = parse_json_stdout(out)
        trace = [json.loads(line) for line in Path(payload["trace"]).read_text().splitlines()]
        ends = [e for e in trace if e["event"] == "node_end" and e["node"] == "rev"]
        assert ends, trace
        outputs = ends[0]["outputs"]
        assert outputs["_invoked"] == "agent:code-reviewer"
        assert outputs["_args"] == {"pr": 42}
    finally:
        flow_path.unlink(missing_ok=True)


def test_hook_kind_executes_real_script(tmp_path):
    """kind=hook execs .opencode/hooks/{name}.sh, parses JSON stdout."""
    hook_dir = REPO / ".opencode" / "hooks"
    hook_dir.mkdir(parents=True, exist_ok=True)
    hook_path = hook_dir / "flow-test-echo.sh"
    hook_path.write_text(
        "#!/usr/bin/env bash\nset -e\necho \"{\\\"got\\\": $FLOW_NODE_ARGS}\"\n"
    )
    hook_path.chmod(0o755)
    flow = {
        "flow_id": "hook-exec",
        "version": 1,
        "confidentiality": "N1",
        "state": {},
        "nodes": [
            {"id": "h1", "kind": "hook", "invoke": "flow-test-echo", "args": {"x": 1}},
        ],
        "edges": [{"from": "h1", "to": "END"}],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    flow_path = REPO / ".scm" / "flows" / "hook-exec.flow.yaml"
    flow_path.write_text(yaml.safe_dump(flow))
    try:
        rc, out, err = run_cli("run", "hook-exec")
        assert rc == 0, err
        payload = parse_json_stdout(out)
        trace = [json.loads(line) for line in Path(payload["trace"]).read_text().splitlines()]
        ends = [e for e in trace if e["event"] == "node_end" and e["node"] == "h1"]
        assert ends, trace
        outputs = ends[0]["outputs"]
        assert outputs["got"] == {"x": 1}, outputs
    finally:
        flow_path.unlink(missing_ok=True)
        hook_path.unlink(missing_ok=True)


def test_hook_missing_fails_node():
    flow = {
        "flow_id": "hook-missing",
        "version": 1,
        "confidentiality": "N1",
        "state": {},
        "nodes": [
            {"id": "h1", "kind": "hook", "invoke": "nope-does-not-exist-9999"},
        ],
        "edges": [{"from": "h1", "to": "END"}],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    flow_path = REPO / ".scm" / "flows" / "hook-missing.flow.yaml"
    flow_path.write_text(yaml.safe_dump(flow))
    try:
        rc, out, err = run_cli("run", "hook-missing")
        # Runner exits non-zero on node failure
        assert rc != 0
        payload = json.loads(out) if out.strip() else {}
        assert payload.get("ok") is False
    finally:
        flow_path.unlink(missing_ok=True)


def test_court_flow_dry_run_orders_judges_in_one_wave():
    """code-review-court flow: judges share parallel_group=judges."""
    rc, out, err = run_cli("run", "code-review-court", "--dry-run")
    assert rc == 0, err
    payload = parse_json_stdout(out)
    assert payload["dry_run"] is True
    order = payload["order"]
    # all 5 judges + fetch-diff + aggregate must be present
    expected = {"fetch-diff", "judge-correctness", "judge-architecture",
                "judge-security", "judge-cognitive", "judge-spec", "aggregate"}
    assert expected <= set(order), order
    # fetch-diff before all judges; aggregate last
    fetch_idx = order.index("fetch-diff")
    agg_idx = order.index("aggregate")
    for j in ["judge-correctness", "judge-architecture", "judge-security",
              "judge-cognitive", "judge-spec"]:
        assert fetch_idx < order.index(j) < agg_idx, (j, order)


def test_command_bridge_with_exec_directive(tmp_path):
    """Slice 3: a command file with `exec:` frontmatter is executed."""
    cmd_dir = REPO / ".opencode" / "commands"
    cmd_path = cmd_dir / "flow-test-bridge.md"
    cmd_path.write_text(
        "---\n"
        "exec: python3 -c \"import os,json; print(json.dumps({'echoed': os.environ['FLOW_NODE_ARGS']}))\"\n"
        "---\n# bridge test\n"
    )
    flow = {
        "flow_id": "cmd-bridge",
        "version": 1,
        "confidentiality": "N1",
        "state": {},
        "nodes": [
            {"id": "c1", "kind": "command", "invoke": "/flow-test-bridge", "args": {"k": "v"}},
        ],
        "edges": [{"from": "c1", "to": "END"}],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    flow_path = REPO / ".scm" / "flows" / "cmd-bridge.flow.yaml"
    flow_path.write_text(yaml.safe_dump(flow))
    try:
        rc, out, err = run_cli("run", "cmd-bridge")
        assert rc == 0, err
        payload = parse_json_stdout(out)
        trace = [json.loads(line) for line in Path(payload["trace"]).read_text().splitlines()]
        ends = [e for e in trace if e["event"] == "node_end" and e["node"] == "c1"]
        assert ends, trace
        outputs = ends[0]["outputs"]
        assert "echoed" in outputs, outputs
        assert json.loads(outputs["echoed"]) == {"k": "v"}
    finally:
        flow_path.unlink(missing_ok=True)
        cmd_path.unlink(missing_ok=True)


def test_singleton_does_not_emit_wave_events(tmp_path):
    """Sequential single-node sections do NOT emit wave_start/wave_end."""
    rc, out, _ = run_cli("run", "hello-world")
    assert rc == 0
    payload = parse_json_stdout(out)
    trace = [json.loads(line) for line in Path(payload["trace"]).read_text().splitlines()]
    waves = [e for e in trace if e["event"] in ("wave_start", "wave_end")]
    assert waves == [], trace


# ─────────────────────────────────────────────────────────────────────────────
# Slice 4 — subflows + idempotent cache + obsidian renderer
# ─────────────────────────────────────────────────────────────────────────────

CACHE_DIR = REPO / "output" / "flows" / "_cache"
OBSIDIAN_OUT = REPO / "output" / "obsidian" / "flows"


def _events(payload: dict) -> list[dict]:
    trace = Path(payload["trace"])
    return [json.loads(line) for line in trace.read_text().splitlines()]


def test_idempotent_cache_hit_emits_event(tmp_path):
    """A node with idempotent: true reuses cached output on second run."""
    flow = {
        "flow_id": "cache-hit",
        "version": 1,
        "confidentiality": "N1",
        "nodes": [
            {"id": "n", "kind": "skill", "invoke": "nonce_skill",
             "args": {"label": "stable"}, "idempotent": True},
        ],
        "edges": [{"from": "n", "to": "END"}],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    flow_path = REPO / ".scm" / "flows" / "cache-hit.flow.yaml"
    flow_path.write_text(yaml.safe_dump(flow))
    try:
        # Clear any prior cache so first run is a miss
        if CACHE_DIR.exists():
            for p in CACHE_DIR.glob("*.json"):
                p.unlink()
        rc, out, err = run_cli("run", "cache-hit")
        assert rc == 0, err
        p1 = parse_json_stdout(out)
        nonce_first = next(e for e in _events(p1) if e["event"] == "node_end")["outputs"]["nonce"]
        # Second run: should hit cache, same nonce, emits node_cache_hit
        rc, out, err = run_cli("run", "cache-hit")
        assert rc == 0, err
        p2 = parse_json_stdout(out)
        evs = _events(p2)
        nonce_second = next(e for e in evs if e["event"] == "node_end")["outputs"]["nonce"]
        assert nonce_first == nonce_second, "cache should reuse output"
        assert any(e["event"] == "node_cache_hit" for e in evs)
        assert next(e for e in evs if e["event"] == "node_end")["cache_hit"] is True
    finally:
        flow_path.unlink(missing_ok=True)


def test_idempotent_cache_miss_when_args_change(tmp_path):
    """Different args produce different hash → different cache slot, no hit."""
    base = {
        "flow_id": "cache-args-a",
        "version": 1,
        "confidentiality": "N1",
        "nodes": [
            {"id": "n", "kind": "skill", "invoke": "nonce_skill",
             "args": {"label": "A"}, "idempotent": True},
        ],
        "edges": [{"from": "n", "to": "END"}],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    a = REPO / ".scm" / "flows" / "cache-args-a.flow.yaml"
    a.write_text(yaml.safe_dump(base))
    b_dict = dict(base, flow_id="cache-args-b")
    b_dict["nodes"] = [dict(base["nodes"][0], args={"label": "B"})]
    b = REPO / ".scm" / "flows" / "cache-args-b.flow.yaml"
    b.write_text(yaml.safe_dump(b_dict))
    try:
        rc, out, _ = run_cli("run", "cache-args-a")
        assert rc == 0
        n_a = next(e for e in _events(parse_json_stdout(out)) if e["event"] == "node_end")["outputs"]["nonce"]
        rc, out, _ = run_cli("run", "cache-args-b")
        assert rc == 0
        n_b = next(e for e in _events(parse_json_stdout(out)) if e["event"] == "node_end")["outputs"]["nonce"]
        assert n_a != n_b, "different args must NOT share cache slot"
    finally:
        a.unlink(missing_ok=True)
        b.unlink(missing_ok=True)


def test_non_idempotent_node_never_caches(tmp_path):
    """idempotent: false (default) → fresh execution every run."""
    flow = {
        "flow_id": "no-cache",
        "version": 1,
        "confidentiality": "N1",
        "nodes": [
            {"id": "n", "kind": "skill", "invoke": "nonce_skill", "args": {"label": "x"}},
        ],
        "edges": [{"from": "n", "to": "END"}],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    flow_path = REPO / ".scm" / "flows" / "no-cache.flow.yaml"
    flow_path.write_text(yaml.safe_dump(flow))
    try:
        rc, out, _ = run_cli("run", "no-cache")
        assert rc == 0
        n1 = next(e for e in _events(parse_json_stdout(out)) if e["event"] == "node_end")["outputs"]["nonce"]
        rc, out, _ = run_cli("run", "no-cache")
        assert rc == 0
        evs = _events(parse_json_stdout(out))
        n2 = next(e for e in evs if e["event"] == "node_end")["outputs"]["nonce"]
        assert n1 != n2, "non-idempotent must produce fresh output"
        assert not any(e["event"] == "node_cache_hit" for e in evs)
    finally:
        flow_path.unlink(missing_ok=True)


def test_subflow_invokes_child_flow(tmp_path):
    """A subflow node runs another .flow.yaml and surfaces its flow: state."""
    child = {
        "flow_id": "sub-child",
        "version": 1,
        "confidentiality": "N1",
        "state": {"answer": 42},
        "nodes": [{"id": "set", "kind": "skill", "invoke": "set_key_skill",
                   "args": {"key": "answer", "value": 99}}],
        "edges": [{"from": "set", "to": "END"}],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    parent = {
        "flow_id": "sub-parent",
        "version": 1,
        "confidentiality": "N1",
        "nodes": [{"id": "call", "kind": "subflow", "invoke": "sub-child"}],
        "edges": [{"from": "call", "to": "END"}],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    cp = REPO / ".scm" / "flows" / "sub-child.flow.yaml"
    pp = REPO / ".scm" / "flows" / "sub-parent.flow.yaml"
    cp.write_text(yaml.safe_dump(child))
    pp.write_text(yaml.safe_dump(parent))
    try:
        rc, out, err = run_cli("run", "sub-parent")
        assert rc == 0, err
        evs = _events(parse_json_stdout(out))
        node_end = next(e for e in evs if e["event"] == "node_end")
        outs = node_end["outputs"]
        assert outs["_invoked"] == "subflow:sub-child"
        assert outs["_subflow_depth"] == 1
        # Child flow set answer=99 in flow: namespace; surfaced under outputs.
        assert outs["outputs"]["answer"] == 99, outs
    finally:
        cp.unlink(missing_ok=True)
        pp.unlink(missing_ok=True)


def test_subflow_depth_limit_enforced(tmp_path):
    """Recursion depth > 3 must error out cleanly."""
    # Self-recursive flow: foo invokes foo. Each level increments depth env.
    rec = {
        "flow_id": "rec-self",
        "version": 1,
        "confidentiality": "N1",
        "nodes": [{"id": "loop", "kind": "subflow", "invoke": "rec-self"}],
        "edges": [{"from": "loop", "to": "END"}],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    fp = REPO / ".scm" / "flows" / "rec-self.flow.yaml"
    fp.write_text(yaml.safe_dump(rec))
    try:
        rc, out, err = run_cli("run", "rec-self")
        assert rc != 0 or '"ok": false' in out
        # Either CLI returns non-zero, or run reports failure with depth msg.
        combined = out + err
        assert "depth" in combined.lower() or "subflow" in combined.lower()
    finally:
        fp.unlink(missing_ok=True)


def test_subflow_unknown_target_fails(tmp_path):
    """Subflow pointing to nonexistent flow_id surfaces error."""
    parent = {
        "flow_id": "sub-missing",
        "version": 1,
        "confidentiality": "N1",
        "nodes": [{"id": "call", "kind": "subflow", "invoke": "does-not-exist-zzz"}],
        "edges": [{"from": "call", "to": "END"}],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    pp = REPO / ".scm" / "flows" / "sub-missing.flow.yaml"
    pp.write_text(yaml.safe_dump(parent))
    try:
        rc, out, err = run_cli("run", "sub-missing")
        # ok=false expected
        assert rc != 0 or '"ok": false' in out, (rc, out, err)
        combined = out + err
        assert "subflow not found" in combined or "not found" in combined.lower()
    finally:
        pp.unlink(missing_ok=True)


def test_obsidian_renderer_renders_all_flows(tmp_path):
    """flow_to_obsidian.py renders one note per flow with backlinks + Mermaid."""
    renderer = REPO / "scripts" / "flow_to_obsidian.py"
    out_dir = tmp_path / "obs"
    proc = subprocess.run(
        [sys.executable, str(renderer), "--out", str(out_dir), "hello-world"],
        cwd=REPO, capture_output=True, text=True,
    )
    assert proc.returncode == 0, proc.stderr
    note = out_dir / "flow-hello-world.md"
    assert note.exists()
    md = note.read_text()
    assert "# Flow: hello-world" in md
    assert "```mermaid" in md
    assert "## Backlinks" in md
    assert "[[command-help]]" in md  # the hello-world flow invokes /help


def test_obsidian_renderer_handles_subflow_backlink(tmp_path):
    """Subflow nodes must produce [[flow-<id>]] backlinks."""
    flow = {
        "flow_id": "obs-sub",
        "version": 1,
        "confidentiality": "N1",
        "nodes": [{"id": "call", "kind": "subflow", "invoke": "hello-world"}],
        "edges": [{"from": "call", "to": "END"}],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }
    fp = REPO / ".scm" / "flows" / "obs-sub.flow.yaml"
    fp.write_text(yaml.safe_dump(flow))
    out_dir = tmp_path / "obs"
    try:
        proc = subprocess.run(
            [sys.executable, str(REPO / "scripts" / "flow_to_obsidian.py"),
             "--out", str(out_dir), "obs-sub"],
            cwd=REPO, capture_output=True, text=True,
        )
        assert proc.returncode == 0, proc.stderr
        md = (out_dir / "flow-obs-sub.md").read_text()
        assert "[[flow-hello-world]]" in md
    finally:
        fp.unlink(missing_ok=True)


def test_three_migrated_flows_validate():
    """Slice 4 closure §3.4: sprint-nocturno, debt-analyze, pr-plan must validate."""
    validator = REPO / "scripts" / "flow_validate.py"
    for fid in ("sprint-nocturno", "debt-analyze", "pr-plan"):
        proc = subprocess.run(
            [sys.executable, str(validator), fid],
            cwd=REPO, capture_output=True, text=True,
        )
        assert proc.returncode == 0, f"{fid}: {proc.stdout}\n{proc.stderr}"
        assert "[OK]" in proc.stdout, proc.stdout
