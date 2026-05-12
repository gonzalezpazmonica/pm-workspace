"""Tests for scripts/flow_validate.py — Slice 1 of SPEC-AGENTIC-FLOW-GRAPH."""
from __future__ import annotations
import json
import subprocess
import sys
from pathlib import Path
import textwrap

import pytest
import yaml

REPO = Path(__file__).resolve().parents[2]
VALIDATE = REPO / "scripts" / "flow_validate.py"


def run(target: str, cwd: Path) -> tuple[int, str, str]:
    """Run the COPY of flow_validate.py inside cwd, so REPO_ROOT resolves there."""
    script = cwd / "scripts" / "flow_validate.py"
    proc = subprocess.run(
        [sys.executable, str(script), target, "--json"],
        cwd=cwd, capture_output=True, text=True
    )
    return proc.returncode, proc.stdout, proc.stderr


def write_flow(tmp: Path, name: str, body: dict) -> Path:
    flow_dir = tmp / ".scm" / "flows"
    flow_dir.mkdir(parents=True, exist_ok=True)
    p = flow_dir / f"{name}.flow.yaml"
    p.write_text(yaml.safe_dump(body, sort_keys=False))
    return p


def setup_repo(tmp: Path) -> None:
    (tmp / "schemas").mkdir(parents=True, exist_ok=True)
    (tmp / "schemas" / "flow.schema.json").write_bytes(
        (REPO / "schemas" / "flow.schema.json").read_bytes()
    )
    scripts = tmp / "scripts"
    scripts.mkdir(parents=True, exist_ok=True)
    (scripts / "flow_validate.py").write_bytes(VALIDATE.read_bytes())


def base_flow() -> dict:
    return {
        "flow_id": "demo",
        "version": 1,
        "confidentiality": "N1",
        "nodes": [
            {"id": "step-a", "kind": "command", "invoke": "/help"}
        ],
        "edges": [
            {"from": "step-a", "to": "END"}
        ],
        "guards": {"max_iterations": 1, "max_duration_minutes": 1},
    }


def test_minimal_flow_validates(tmp_path):
    setup_repo(tmp_path)
    write_flow(tmp_path, "demo", base_flow())
    rc, out, _ = run("all", tmp_path)
    assert rc == 0, out
    rep = json.loads(out)
    assert rep["ok"] is True
    assert len(rep["flows"]) == 1
    assert rep["flows"][0]["ok"] is True


def test_filename_must_match_flow_id(tmp_path):
    setup_repo(tmp_path)
    body = base_flow()
    body["flow_id"] = "demo"
    write_flow(tmp_path, "wrong-name", body)
    rc, out, _ = run("all", tmp_path)
    assert rc != 0
    rep = json.loads(out)
    assert any("filename mismatch" in e for e in rep["flows"][0]["errors"])


def test_missing_required_field_fails_schema(tmp_path):
    setup_repo(tmp_path)
    body = base_flow()
    del body["guards"]
    write_flow(tmp_path, "demo", body)
    rc, out, _ = run("all", tmp_path)
    assert rc == 1
    rep = json.loads(out)
    assert any("guards" in e for e in rep["flows"][0]["errors"])


def test_unknown_node_reference_in_edge(tmp_path):
    setup_repo(tmp_path)
    body = base_flow()
    body["edges"][0]["from"] = "ghost"
    write_flow(tmp_path, "demo", body)
    rc, out, _ = run("all", tmp_path)
    assert rc == 1
    rep = json.loads(out)
    assert any("unknown node: ghost" in e for e in rep["flows"][0]["errors"])


def test_cel_invalid_compile_returns_code_2(tmp_path):
    setup_repo(tmp_path)
    body = base_flow()
    body["edges"][0]["when"] = "this is not @ valid CEL ##"
    write_flow(tmp_path, "demo", body)
    rc, out, _ = run("all", tmp_path)
    assert rc == 2, out
    rep = json.loads(out)
    assert any("CEL[" in e and "compile error" in e for e in rep["flows"][0]["errors"])


def test_cel_valid_simple_expression(tmp_path):
    setup_repo(tmp_path)
    body = base_flow()
    body["edges"][0]["when"] = "state.x == 1"
    write_flow(tmp_path, "demo", body)
    rc, out, _ = run("all", tmp_path)
    assert rc == 0, out


def test_cycle_without_exit_when_rejected(tmp_path):
    setup_repo(tmp_path)
    body = base_flow()
    body["nodes"] = [
        {"id": "a", "kind": "command", "invoke": "/help"},
        {"id": "b", "kind": "command", "invoke": "/help"},
    ]
    body["edges"] = [
        {"from": "a", "to": "b"},
        {"from": "b", "to": "a"},
    ]
    write_flow(tmp_path, "demo", body)
    rc, out, _ = run("all", tmp_path)
    assert rc == 1
    rep = json.loads(out)
    assert any("cycle without exit_when" in e for e in rep["flows"][0]["errors"])


def test_cycle_with_exit_when_accepted(tmp_path):
    setup_repo(tmp_path)
    body = base_flow()
    body["nodes"] = [
        {"id": "a", "kind": "command", "invoke": "/help", "exit_when": "state.done == true"},
        {"id": "b", "kind": "command", "invoke": "/help", "exit_when": "state.done == true"},
    ]
    body["edges"] = [
        {"from": "a", "to": "b"},
        {"from": "b", "to": "a"},
    ]
    write_flow(tmp_path, "demo", body)
    rc, out, _ = run("all", tmp_path)
    assert rc == 0, out


def test_invalid_confidentiality_rejected(tmp_path):
    setup_repo(tmp_path)
    body = base_flow()
    body["confidentiality"] = "N99"
    write_flow(tmp_path, "demo", body)
    rc, out, _ = run("all", tmp_path)
    assert rc == 1


def test_real_hello_world_flow_validates():
    """Sanity check: the flow shipped in this slice validates against the real schema."""
    proc = subprocess.run(
        [sys.executable, str(VALIDATE), "hello-world"],
        cwd=REPO, capture_output=True, text=True
    )
    assert proc.returncode == 0, proc.stdout + proc.stderr
