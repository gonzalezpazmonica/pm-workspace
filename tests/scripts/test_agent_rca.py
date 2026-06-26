"""tests/scripts/test_agent_rca.py — SPEC-108

Tests for scripts/agent-rca-analyzer.py: Agent Root Cause Analysis pipeline.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

# ── Load module ───────────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "agent-rca-analyzer.py"


def _load():
    spec = importlib.util.spec_from_file_location("agent_rca_analyzer", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["agent_rca_analyzer"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load()
analyze = mod.analyze


# ── test 1: LOGIC error → spec re-review suggestion ──────────────────────────
def test_logic_error_triggers_spec_review():
    result = analyze("incorrect algorithm in sorting logic", "dotnet-developer")
    assert result["category"] == "LOGIC"
    assert result["rca_layer"] == "SPEC_REVIEW"
    assert "spec" in result["fix_suggestion"].lower() or "review" in result["fix_suggestion"].lower()


# ── test 2: CAPACITY error → context pruning suggestion ──────────────────────
def test_capacity_error_triggers_context_pruning():
    result = analyze("context window exceeded — token limit reached", "code-reviewer")
    assert result["category"] == "CAPACITY"
    assert result["rca_layer"] == "CONTEXT_PRUNING"
    assert "context" in result["fix_suggestion"].lower() or "prune" in result["fix_suggestion"].lower()


# ── test 3: SCOPE error → task decomposition suggestion ──────────────────────
def test_scope_error_triggers_task_decomposition():
    result = analyze("modified 7 files instead of 2, scope exceeded boundary")
    assert result["category"] == "SCOPE"
    assert result["rca_layer"] == "TASK_DECOMPOSITION"
    assert "decompos" in result["fix_suggestion"].lower()


# ── test 4: TRANSIENT error → retry suggestion ───────────────────────────────
def test_transient_error_triggers_retry():
    result = analyze("timeout after 30s — service unavailable")
    assert result["category"] == "TRANSIENT"
    assert result["rca_layer"] == "RETRY"
    assert "retry" in result["fix_suggestion"].lower()


# ── test 5: output has all required fields ───────────────────────────────────
def test_output_has_required_fields():
    result = analyze("test failed")
    for key in ["root_cause", "category", "fix_suggestion", "confidence", "rca_layer"]:
        assert key in result, f"Missing key: {key}"


# ── test 6: confidence decreases without context ─────────────────────────────
def test_confidence_lower_without_context():
    with_ctx = analyze("logic error in auth module", context="dotnet-developer")
    without_ctx = analyze("logic error in auth module", context="")
    assert with_ctx["confidence"] >= without_ctx["confidence"]


# ── test 7: CLI output is valid JSON ─────────────────────────────────────────
def test_cli_output_is_json(monkeypatch):
    lines: list[str] = []
    monkeypatch.setattr("builtins.print", lambda *a, **kw: lines.append(" ".join(str(x) for x in a)))
    rc = mod.main(["--error", "timeout error", "--context", "test context"])
    assert rc == 0
    parsed = json.loads("\n".join(lines))
    assert "root_cause" in parsed
    assert "confidence" in parsed


# ── test 8: confidence is in [0, 1] ──────────────────────────────────────────
def test_confidence_in_valid_range():
    for error in ["timeout", "logic error", "json parse fail", "context exceeded"]:
        result = analyze(error)
        assert 0.0 <= result["confidence"] <= 1.0


# ── test 9: root_cause includes error excerpt ────────────────────────────────
def test_root_cause_includes_error_excerpt():
    error = "NullReferenceException in UserController.GetById at line 42"
    result = analyze(error)
    assert "NullReferenceException" in result["root_cause"] or "Signal" in result["root_cause"]


# ── test 10: VALIDATION error → AC review suggestion ─────────────────────────
def test_validation_error_triggers_ac_review():
    result = analyze("acceptance criteria AC-3 failed — output does not match expected")
    assert result["category"] == "VALIDATION"
    assert result["rca_layer"] == "AC_REVIEW"
